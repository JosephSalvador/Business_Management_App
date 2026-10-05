using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

public sealed class IdentityEndpointsTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public IdentityEndpointsTests(BusinessOsApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    public Task InitializeAsync() => Task.CompletedTask;

    public Task DisposeAsync()
    {
        _client.Dispose();
        return Task.CompletedTask;
    }

    private static JsonElement Body(string json) => JsonSerializer.Deserialize<JsonElement>(json);

    private static string GetProperty(JsonElement doc, params string[] path)
    {
        JsonElement current = doc;
        foreach (var part in path)
        {
            if (current.ValueKind == JsonValueKind.Array && int.TryParse(part, out var index))
            {
                current = current[index];
            }
            else
            {
                current = current.GetProperty(part);
            }
        }
        return current.ToString();
    }

    private static bool GetBool(JsonElement doc, params string[] path)
    {
        JsonElement current = doc;
        foreach (var part in path)
        {
            if (current.ValueKind == JsonValueKind.Array && int.TryParse(part, out var index))
            {
                current = current[index];
            }
            else
            {
                current = current.GetProperty(part);
            }
        }
        return current.GetBoolean();
    }

    private async Task<(string AccessToken, string TenantId, string UserId)> RegisterAsync(string label)
    {
        var email = $"{label}-{Guid.NewGuid():N}@test.local";
        var response = await TestRegistration.RegisterUnverifiedAsync(_client, label, email);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var code = await TestRegistration.GetLatestVerificationCodeAsync(email);
        var verify = await _client.PostAsJsonAsync("/api/v1/auth/verify-email", new { email, code });
        Assert.Equal(HttpStatusCode.NoContent, verify.StatusCode);

        var login = await _client.PostAsJsonAsync("/api/v1/auth/login", new { identifier = email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var doc = Body(await login.Content.ReadAsStringAsync());
        return (
            GetProperty(doc, "accessToken"),
            GetProperty(doc, "user", "tenantId"),
            GetProperty(doc, "user", "id"));
    }

    private async Task<string> RegisterLimitedUserAsync(string label, Guid tenantId, params string[] permissions)
    {
        using var db = CreateDbContext();
        var catalog = await db.Permissions.Where(p => permissions.Contains(p.Name)).ToListAsync();
        var role = Role.Create(tenantId, $"{label} Role");
        role.Grant(catalog);
        await db.Roles.AddAsync(role);

        var hash = await db.Users
            .Where(u => u.TenantId == tenantId)
            .Select(u => u.PasswordHash)
            .FirstAsync();
        var user = User.Create(Guid.NewGuid(), tenantId, $"{label}-{Guid.NewGuid():N}@test.local", hash, label, phone: null);
        user.AssignRole(role);
        user.MarkEmailVerified();
        await db.Users.AddAsync(user);
        await db.SaveChangesAsync();

        var login = await _client.PostAsJsonAsync("/api/v1/auth/login", new { identifier = user.Email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        return GetProperty(Body(await login.Content.ReadAsStringAsync()), "tokens", "accessToken");
    }

    private async Task<Guid> GetAdminRoleIdAsync(Guid tenantId)
    {
        using var db = CreateDbContext();
        return await db.Roles
            .Where(r => r.TenantId == tenantId && r.IsSystem && r.Name == SystemRoles.Administrator)
            .Select(r => r.Id)
            .SingleAsync();
    }

    private async Task<Guid> GetBranchIdAsync(Guid tenantId)
    {
        using var db = CreateDbContext();
        return await db.Branches.Where(b => b.TenantId == tenantId).Select(b => b.Id).FirstAsync();
    }

    private void Authorize(string token) => _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

    private BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }

    [Fact]
    public async Task Endpoints_RequireAuthentication()
    {
        foreach (var path in new[] { "/api/v1/users", "/api/v1/users/me", "/api/v1/roles", "/api/v1/permissions" })
        {
            var response = await _client.GetAsync(path);
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        }

        var post = await _client.PostAsJsonAsync("/api/v1/users", new { });
        Assert.Equal(HttpStatusCode.Unauthorized, post.StatusCode);
    }

    [Fact]
    public async Task Admin_UserEndpoints_FullLifecycle()
    {
        var (token, tenantId, adminUserId) = await RegisterAsync("adminusers");
        var adminRoleId = await GetAdminRoleIdAsync(Guid.Parse(tenantId));
        var branchId = await GetBranchIdAsync(Guid.Parse(tenantId));
        Authorize(token);

        var listed = await _client.GetAsync("/api/v1/users?page=1&pageSize=50");
        Assert.Equal(HttpStatusCode.OK, listed.StatusCode);
        var listDoc = Body(await listed.Content.ReadAsStringAsync());
        Assert.True(listDoc.GetProperty("total").GetInt32() >= 1);

        var fetched = await _client.GetAsync($"/api/v1/users/{adminUserId}");
        Assert.Equal(HttpStatusCode.OK, fetched.StatusCode);

        var created = await _client.PostAsJsonAsync("/api/v1/users", new
        {
            email = $"cashier-{Guid.NewGuid():N}@test.local",
            password = "Passw0rd!",
            fullName = "Cashier",
            phone = TestPhones.Next(),
            roleIds = new[] { adminRoleId },
            branchIds = new[] { branchId },
            defaultBranchId = branchId,
        });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var createdDoc = Body(await created.Content.ReadAsStringAsync());
        Assert.Equal("Cashier", GetProperty(createdDoc, "fullName"));
        var cashierId = GetProperty(createdDoc, "id");

        var updated = await _client.PutAsJsonAsync($"/api/v1/users/{cashierId}", new { fullName = "Senior Cashier", phone = TestPhones.Next() });
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        Assert.Equal("Senior Cashier", GetProperty(Body(await updated.Content.ReadAsStringAsync()), "fullName"));

        var roles = await _client.PutAsJsonAsync($"/api/v1/users/{cashierId}/roles", new { roleIds = new[] { adminRoleId } });
        Assert.Equal(HttpStatusCode.OK, roles.StatusCode);

        var branches = await _client.GetAsync($"/api/v1/users/{cashierId}/branches");
        Assert.Equal(HttpStatusCode.OK, branches.StatusCode);

        var setBranches = await _client.PutAsJsonAsync($"/api/v1/users/{cashierId}/branches", new { branchIds = new[] { branchId }, defaultBranchId = branchId });
        Assert.Equal(HttpStatusCode.OK, setBranches.StatusCode);

        var status = await _client.PatchAsJsonAsync($"/api/v1/users/{cashierId}/status", new { isActive = false });
        Assert.Equal(HttpStatusCode.OK, status.StatusCode);
        Assert.False(GetBool(Body(await status.Content.ReadAsStringAsync()), "isActive"));

        var deleted = await _client.DeleteAsync($"/api/v1/users/{cashierId}");
        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);

        var afterDelete = await _client.GetAsync($"/api/v1/users/{cashierId}");
        Assert.Equal(HttpStatusCode.OK, afterDelete.StatusCode);
        Assert.False(GetBool(Body(await afterDelete.Content.ReadAsStringAsync()), "isActive"));
    }

    [Fact]
    public async Task Admin_RoleEndpoints_FullLifecycle()
    {
        var (token, tenantId, _) = await RegisterAsync("adminroles");
        var adminRoleId = await GetAdminRoleIdAsync(Guid.Parse(tenantId));
        Authorize(token);

        var listed = await _client.GetAsync("/api/v1/roles");
        Assert.Equal(HttpStatusCode.OK, listed.StatusCode);
        var listDoc = Body(await listed.Content.ReadAsStringAsync());
        Assert.Contains(listDoc.EnumerateArray(), r => GetProperty(r, "id") == adminRoleId.ToString());

        var fetched = await _client.GetAsync($"/api/v1/roles/{adminRoleId}");
        Assert.Equal(HttpStatusCode.OK, fetched.StatusCode);
        Assert.True(GetBool(Body(await fetched.Content.ReadAsStringAsync()), "isSystem"));

        var created = await _client.PostAsJsonAsync("/api/v1/roles", new { name = "Cashier", description = "Rings sales" });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var roleDoc = Body(await created.Content.ReadAsStringAsync());
        Assert.Equal("Cashier", GetProperty(roleDoc, "name"));
        var roleId = GetProperty(roleDoc, "id");

        var updated = await _client.PutAsJsonAsync($"/api/v1/roles/{roleId}", new { name = "Senior Cashier", description = "Rings and closes" });
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        Assert.Equal("Senior Cashier", GetProperty(Body(await updated.Content.ReadAsStringAsync()), "name"));

        var permissions = await _client.GetAsync($"/api/v1/roles/{roleId}/permissions");
        Assert.Equal(HttpStatusCode.OK, permissions.StatusCode);

        var setPermissions = await _client.PutAsJsonAsync($"/api/v1/roles/{roleId}/permissions", new { permissionNames = new[] { "Sales.Create", "Users.View" } });
        Assert.Equal(HttpStatusCode.OK, setPermissions.StatusCode);
        var permDoc = Body(await setPermissions.Content.ReadAsStringAsync());
        var permNames = permDoc.GetProperty("permissionNames").EnumerateArray().Select(p => p.GetString()).ToArray();
        Assert.Equal(new[] { "Sales.Create", "Users.View" }, permNames);

        var deleted = await _client.DeleteAsync($"/api/v1/roles/{roleId}");
        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);

        var catalog = await _client.GetAsync("/api/v1/permissions");
        Assert.Equal(HttpStatusCode.OK, catalog.StatusCode);
        var catalogDoc = Body(await catalog.Content.ReadAsStringAsync());
        Assert.Contains(catalogDoc.EnumerateArray(), p => GetProperty(p, "name") == "Roles.Manage");
    }

    [Fact]
    public async Task UsersViewOnly_CanReadButCannotMutateUsers()
    {
        var (_, tenantId, adminUserId) = await RegisterAsync("viewer");
        var token = await RegisterLimitedUserAsync("viewer", Guid.Parse(tenantId), PermissionNames.UsersView);
        Authorize(token);

        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync("/api/v1/users?page=1&pageSize=10")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync($"/api/v1/users/{adminUserId}")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync($"/api/v1/users/{adminUserId}/branches")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync("/api/v1/permissions")).StatusCode);

        Assert.Equal(HttpStatusCode.Forbidden, (await _client.PostAsJsonAsync("/api/v1/users", new { })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _client.PutAsJsonAsync($"/api/v1/users/{adminUserId}", new { fullName = "Hijacked" })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _client.PutAsJsonAsync($"/api/v1/users/{adminUserId}/roles", new { roleIds = Array.Empty<Guid>() })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _client.PutAsJsonAsync($"/api/v1/users/{adminUserId}/branches", new { branchIds = Array.Empty<Guid>() })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _client.PatchAsJsonAsync($"/api/v1/users/{adminUserId}/status", new { isActive = false })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _client.DeleteAsync($"/api/v1/users/{adminUserId}")).StatusCode);

        Assert.Equal(HttpStatusCode.Forbidden, (await _client.GetAsync("/api/v1/roles")).StatusCode);
    }

    [Fact]
    public async Task RolesViewOnly_CanReadButCannotManageRoles()
    {
        var (_, tenantId, _) = await RegisterAsync("roleviewer");
        var adminRoleId = await GetAdminRoleIdAsync(Guid.Parse(tenantId));
        var token = await RegisterLimitedUserAsync("roleviewer", Guid.Parse(tenantId), PermissionNames.RolesView);
        Authorize(token);

        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync("/api/v1/roles")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync($"/api/v1/roles/{adminRoleId}")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync($"/api/v1/roles/{adminRoleId}/permissions")).StatusCode);

        Assert.Equal(HttpStatusCode.Forbidden, (await _client.PostAsJsonAsync("/api/v1/roles", new { name = "X" })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _client.PutAsJsonAsync($"/api/v1/roles/{adminRoleId}", new { name = "X" })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _client.DeleteAsync($"/api/v1/roles/{adminRoleId}")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _client.PutAsJsonAsync($"/api/v1/roles/{adminRoleId}/permissions", new { permissionNames = new[] { "Users.View" } })).StatusCode);

        Assert.Equal(HttpStatusCode.Forbidden, (await _client.GetAsync("/api/v1/users?page=1&pageSize=10")).StatusCode);
    }

    [Fact]
    public async Task UsersCreateOnly_CanCreateUsersButNothingElse()
    {
        var (_, tenantId, adminUserId) = await RegisterAsync("createonly");
        var adminRoleId = await GetAdminRoleIdAsync(Guid.Parse(tenantId));
        var branchId = await GetBranchIdAsync(Guid.Parse(tenantId));
        var token = await RegisterLimitedUserAsync("createonly", Guid.Parse(tenantId), PermissionNames.UsersCreate);
        Authorize(token);

        var created = await _client.PostAsJsonAsync("/api/v1/users", new
        {
            email = $"made-{Guid.NewGuid():N}@test.local",
            password = "Passw0rd!",
            fullName = "Made",
            roleIds = new[] { adminRoleId },
            branchIds = new[] { branchId },
        });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);

        Assert.Equal(HttpStatusCode.Forbidden, (await _client.GetAsync("/api/v1/users?page=1&pageSize=10")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _client.DeleteAsync($"/api/v1/users/{adminUserId}")).StatusCode);
    }

    [Fact]
    public async Task UsersUpdateOnly_CanMutateUsersButNotCreateOrDelete()
    {
        var (_, tenantId, adminUserId) = await RegisterAsync("updateonly");
        var adminRoleId = await GetAdminRoleIdAsync(Guid.Parse(tenantId));
        var branchId = await GetBranchIdAsync(Guid.Parse(tenantId));
        var token = await RegisterLimitedUserAsync("updateonly", Guid.Parse(tenantId), PermissionNames.UsersUpdate);
        Authorize(token);

        Assert.Equal(HttpStatusCode.OK, (await _client.PutAsJsonAsync($"/api/v1/users/{adminUserId}", new { fullName = "Renamed" })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _client.PutAsJsonAsync($"/api/v1/users/{adminUserId}/roles", new { roleIds = new[] { adminRoleId } })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _client.PutAsJsonAsync($"/api/v1/users/{adminUserId}/branches", new { branchIds = new[] { branchId }, defaultBranchId = branchId })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _client.PatchAsJsonAsync($"/api/v1/users/{adminUserId}/status", new { isActive = true })).StatusCode);

        Assert.Equal(HttpStatusCode.Forbidden, (await _client.PostAsJsonAsync("/api/v1/users", new { })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _client.DeleteAsync($"/api/v1/users/{adminUserId}")).StatusCode);
    }

    [Fact]
    public async Task UsersDeleteOnly_CanDeleteButNotCreate()
    {
        var (token, tenantId, adminUserId) = await RegisterAsync("deleteonly");
        var adminRoleId = await GetAdminRoleIdAsync(Guid.Parse(tenantId));
        var branchId = await GetBranchIdAsync(Guid.Parse(tenantId));
        Authorize(token);

        var created = await _client.PostAsJsonAsync("/api/v1/users", new
        {
            email = $"target-{Guid.NewGuid():N}@test.local",
            password = "Passw0rd!",
            fullName = "Target",
            roleIds = new[] { adminRoleId },
            branchIds = new[] { branchId },
        });
        var targetId = GetProperty(Body(await created.Content.ReadAsStringAsync()), "id");

        var deleteOnly = await RegisterLimitedUserAsync("deleteonly", Guid.Parse(tenantId), PermissionNames.UsersDelete);
        Authorize(deleteOnly);

        var deleted = await _client.DeleteAsync($"/api/v1/users/{targetId}");
        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);

        Assert.Equal(HttpStatusCode.Forbidden, (await _client.PostAsJsonAsync("/api/v1/users", new { })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _client.GetAsync($"/api/v1/users/{adminUserId}")).StatusCode);
    }

    [Fact]
    public async Task RolesManageOnly_CanManageRolesAndPermissionsButNotAdministerUsers()
    {
        var (_, tenantId, adminUserId) = await RegisterAsync("rolemanager");
        var token = await RegisterLimitedUserAsync("rolemanager", Guid.Parse(tenantId), PermissionNames.RolesManage);
        Authorize(token);

        var created = await _client.PostAsJsonAsync("/api/v1/roles", new { name = "Floor Staff", description = "Sells" });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var roleId = GetProperty(Body(await created.Content.ReadAsStringAsync()), "id");

        var setPermissions = await _client.PutAsJsonAsync($"/api/v1/roles/{roleId}/permissions", new { permissionNames = new[] { "Sales.Create" } });
        Assert.Equal(HttpStatusCode.OK, setPermissions.StatusCode);

        var updated = await _client.PutAsJsonAsync($"/api/v1/roles/{roleId}", new { name = "Floor Staff Lead", description = "Sells and supervises" });
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);

        var deleted = await _client.DeleteAsync($"/api/v1/roles/{roleId}");
        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);

        Assert.Equal(HttpStatusCode.Forbidden, (await _client.GetAsync("/api/v1/roles")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _client.PostAsJsonAsync("/api/v1/users", new { })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _client.PatchAsJsonAsync($"/api/v1/users/{adminUserId}/status", new { isActive = false })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _client.DeleteAsync($"/api/v1/users/{adminUserId}")).StatusCode);
    }

    [Fact]
    public async Task DuplicateEmail_And_DuplicateRoleName_ReturnConflict()
    {
        var (token, tenantId, _) = await RegisterAsync("dupes");
        var adminRoleId = await GetAdminRoleIdAsync(Guid.Parse(tenantId));
        var branchId = await GetBranchIdAsync(Guid.Parse(tenantId));
        Authorize(token);

        var email = $"dupe-{Guid.NewGuid():N}@test.local";
        var payload = new
        {
            email,
            password = "Passw0rd!",
            fullName = "Dupe",
            roleIds = new[] { adminRoleId },
            branchIds = new[] { branchId },
        };
        Assert.Equal(HttpStatusCode.OK, (await _client.PostAsJsonAsync("/api/v1/users", payload)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await _client.PostAsJsonAsync("/api/v1/users", payload)).StatusCode);

        Assert.Equal(HttpStatusCode.OK, (await _client.PostAsJsonAsync("/api/v1/roles", new { name = "Manager" })).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await _client.PostAsJsonAsync("/api/v1/roles", new { name = "Manager" })).StatusCode);
    }

    [Fact]
    public async Task SystemRole_Protection_CannotRenameOrDeleteButCanAdjustPermissions()
    {
        var (token, tenantId, _) = await RegisterAsync("sysrole");
        var adminRoleId = await GetAdminRoleIdAsync(Guid.Parse(tenantId));
        Authorize(token);

        var renamed = await _client.PutAsJsonAsync($"/api/v1/roles/{adminRoleId}", new { name = "Super Admin", description = "x" });
        Assert.Equal(HttpStatusCode.Conflict, renamed.StatusCode);

        var deleted = await _client.DeleteAsync($"/api/v1/roles/{adminRoleId}");
        Assert.Equal(HttpStatusCode.Conflict, deleted.StatusCode);

        var adjust = await _client.PutAsJsonAsync($"/api/v1/roles/{adminRoleId}/permissions", new { permissionNames = new[] { "Users.View" } });
        Assert.Equal(HttpStatusCode.OK, adjust.StatusCode);
        var adjustDoc = Body(await adjust.Content.ReadAsStringAsync());
        Assert.Contains(adjustDoc.GetProperty("permissionNames").EnumerateArray(), p => p.GetString() == "Users.View");
    }

    [Fact]
    public async Task SelfProtection_And_LastAdministratorProtection_ReturnConflict()
    {
        var (token, tenantId, adminUserId) = await RegisterAsync("protect");
        var adminRoleId = await GetAdminRoleIdAsync(Guid.Parse(tenantId));
        var branchId = await GetBranchIdAsync(Guid.Parse(tenantId));
        Authorize(token);

        var selfDeactivate = await _client.PatchAsJsonAsync($"/api/v1/users/{adminUserId}/status", new { isActive = false });
        Assert.Equal(HttpStatusCode.Conflict, selfDeactivate.StatusCode);

        var selfDelete = await _client.DeleteAsync($"/api/v1/users/{adminUserId}");
        Assert.Equal(HttpStatusCode.Conflict, selfDelete.StatusCode);

        var created = await _client.PostAsJsonAsync("/api/v1/users", new
        {
            email = $"admin2-{Guid.NewGuid():N}@test.local",
            password = "Passw0rd!",
            fullName = "Admin Two",
            roleIds = new[] { adminRoleId },
            branchIds = new[] { branchId },
        });
        var admin2Id = GetProperty(Body(await created.Content.ReadAsStringAsync()), "id");

        var deactivated = await _client.PatchAsJsonAsync($"/api/v1/users/{admin2Id}/status", new { isActive = false });
        Assert.Equal(HttpStatusCode.OK, deactivated.StatusCode);

        var updateOnly = await RegisterLimitedUserAsync("updater", Guid.Parse(tenantId), PermissionNames.UsersUpdate);
        Authorize(updateOnly);
        var lastAdmin = await _client.PatchAsJsonAsync($"/api/v1/users/{adminUserId}/status", new { isActive = false });
        Assert.Equal(HttpStatusCode.Conflict, lastAdmin.StatusCode);
    }

    [Fact]
    public async Task ValidationErrors_ReturnBadRequest()
    {
        var (token, tenantId, adminUserId) = await RegisterAsync("valid");
        var adminRoleId = await GetAdminRoleIdAsync(Guid.Parse(tenantId));
        var branchId = await GetBranchIdAsync(Guid.Parse(tenantId));
        Authorize(token);

        var badUser = await _client.PostAsJsonAsync("/api/v1/users", new
        {
            email = "not-an-email",
            password = "weak",
            fullName = "",
            roleIds = new[] { adminRoleId },
            branchIds = new[] { branchId },
        });
        Assert.Equal(HttpStatusCode.BadRequest, badUser.StatusCode);

        var badRole = await _client.PostAsJsonAsync("/api/v1/roles", new { name = "" });
        Assert.Equal(HttpStatusCode.BadRequest, badRole.StatusCode);

        var unknownRole = await _client.PutAsJsonAsync($"/api/v1/users/{adminUserId}/roles", new { roleIds = new[] { Guid.NewGuid() } });
        Assert.Equal(HttpStatusCode.BadRequest, unknownRole.StatusCode);

        var badPermissions = await _client.PutAsJsonAsync($"/api/v1/roles/{adminRoleId}/permissions", new { permissionNames = new[] { "Nope.View" } });
        Assert.Equal(HttpStatusCode.BadRequest, badPermissions.StatusCode);

        var notFound = await _client.GetAsync($"/api/v1/users/{Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.NotFound, notFound.StatusCode);
    }

    [Fact]
    public async Task SwaggerDocument_ListsIdentityEndpointsAndSecurity()
    {
        var response = await _client.GetAsync("/swagger/v1/swagger.json");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var doc = Body(await response.Content.ReadAsStringAsync());
        var paths = doc.GetProperty("paths");
        foreach (var path in new[] { "/api/v1/users", "/api/v1/users/{id}/roles", "/api/v1/users/{id}/status", "/api/v1/roles", "/api/v1/roles/{id}/permissions", "/api/v1/permissions" })
        {
            Assert.True(paths.TryGetProperty(path, out _), $"OpenAPI document is missing path '{path}'.");
        }

        var securitySchemes = doc.GetProperty("components").GetProperty("securitySchemes");
        Assert.True(securitySchemes.TryGetProperty("Bearer", out _), "OpenAPI document must declare the Bearer scheme.");
        Assert.True(doc.TryGetProperty("security", out _), "OpenAPI document must declare a security requirement.");
    }

    [Fact]
    public async Task CrossTenant_UserAndRoleOperations_ReturnNotFound()
    {
        var (_, tenantA, adminUserIdA) = await RegisterAsync("iso-a");
        var adminRoleIdA = await GetAdminRoleIdAsync(Guid.Parse(tenantA));
        var (tokenB, _, _) = await RegisterAsync("iso-b");
        Authorize(tokenB);

        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync($"/api/v1/users/{adminUserIdA}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync($"/api/v1/users/{adminUserIdA}/branches")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.PutAsJsonAsync($"/api/v1/users/{adminUserIdA}", new { fullName = "Hijacked" })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.PatchAsJsonAsync($"/api/v1/users/{adminUserIdA}/status", new { isActive = false })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.DeleteAsync($"/api/v1/users/{adminUserIdA}")).StatusCode);

        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync($"/api/v1/roles/{adminRoleIdA}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.PutAsJsonAsync($"/api/v1/roles/{adminRoleIdA}", new { name = "Hijacked" })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.DeleteAsync($"/api/v1/roles/{adminRoleIdA}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.PutAsJsonAsync($"/api/v1/roles/{adminRoleIdA}/permissions", new { permissionNames = new[] { "Users.View" } })).StatusCode);
    }
}
