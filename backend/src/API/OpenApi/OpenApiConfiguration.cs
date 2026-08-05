using System.Reflection;
using Microsoft.OpenApi;
using Swashbuckle.AspNetCore.SwaggerGen;
using Swashbuckle.AspNetCore.SwaggerUI;

namespace BusinessOS.Api.OpenApi;

public static class OpenApiConfiguration
{
    public static void ConfigureSwagger(SwaggerGenOptions options, Assembly apiAssembly)
    {
        options.SwaggerDoc("v1", new OpenApiInfo
        {
            Title = "Business OS API",
            Version = "v1",
            Description = "Modular business management platform API for the African market.",
            Contact = new OpenApiContact { Name = "Business OS Platform Team" },
        });

        var xmlFile = $"{apiAssembly.GetName().Name}.xml";
        var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
        if (File.Exists(xmlPath))
        {
            options.IncludeXmlComments(xmlPath);
        }

        var bearerScheme = new OpenApiSecurityScheme
        {
            Name = "Authorization",
            Type = SecuritySchemeType.Http,
            Scheme = "bearer",
            BearerFormat = "JWT",
            In = ParameterLocation.Header,
            Description = "Enter 'Bearer' followed by a space and your access token.",
        };
        options.AddSecurityDefinition("Bearer", bearerScheme);

        options.AddSecurityRequirement(_ => new OpenApiSecurityRequirement
        {
            { new OpenApiSecuritySchemeReference("Bearer"), new List<string>() },
        });
    }

    public static void ConfigureSwaggerUi(SwaggerUIOptions options)
    {
        options.SwaggerEndpoint("/swagger/v1/swagger.json", "Business OS API v1");
        options.DocExpansion(DocExpansion.None);
    }
}
