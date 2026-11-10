import React, { useState, useEffect } from 'react';
import {
  Search,
  RefreshCw,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react';
import {
  listTenantProducts,
  updateTenantProduct,
  adjustTenantStock,
  seedStarterCatalog,
} from '../services/api';
import {
  Container,
  Button,
  StatusIndicator,
  Badge,
  Modal,
  Alert,
} from '../ui/primitives';

export default function OmniProductsTable({
  tenantId,
  tenantName,
  onNotification,
}) {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [search, setSearch] = useState('');
  const [lowStockOnly, setLowStockOnly] = useState(false);
  const [page, setPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  // Stock adjustment modal
  const [stockModalProduct, setStockModalProduct] = useState(null);
  const [newStockQty, setNewStockQty] = useState('');
  const [stockReason, setStockReason] = useState(
    'Platform Admin Stock Adjustment'
  );
  const [savingStock, setSavingStock] = useState(false);

  // Edit product modal
  const [editModalProduct, setEditModalProduct] = useState(null);
  const [editForm, setEditForm] = useState({
    name: '',
    barcode: '',
    buyingPrice: 0,
    sellingPrice: 0,
    category: '',
    isActive: true,
  });
  const [savingEdit, setSavingEdit] = useState(false);

  // Starter catalog seed modal
  const [starterPackModal, setStarterPackModal] = useState(false);
  const [seedingLoading, setSeedingLoading] = useState(false);

  const fetchProducts = async () => {
    if (!tenantId) return;
    setLoading(true);
    setError(null);
    try {
      const res = await listTenantProducts(tenantId, {
        search,
        lowStockOnly,
        page,
        pageSize: 25,
      });
      if (res && res.items) {
        setProducts(res.items);
        setTotalCount(res.totalCount || res.items.length);
      } else if (Array.isArray(res)) {
        setProducts(res);
        setTotalCount(res.length);
      } else {
        setProducts([]);
        setTotalCount(0);
      }
    } catch (err) {
      setError(err.message || 'Failed to load products from server.');
      setProducts([]);
      setTotalCount(0);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchProducts();
  }, [tenantId, page, lowStockOnly]);

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    setPage(1);
    fetchProducts();
  };

  const openEditModal = (product) => {
    setEditModalProduct(product);
    setEditForm({
      name: product.name || '',
      barcode: product.barcode || product.sku || '',
      buyingPrice: product.buyingPrice ?? product.costPrice ?? 0,
      sellingPrice: product.sellingPrice ?? product.price ?? 0,
      category: product.category || product.categoryName || 'General',
      isActive: product.isActive !== false,
    });
  };

  const handleSaveEdit = async (e) => {
    if (e) e.preventDefault();
    if (!editModalProduct) return;
    setSavingEdit(true);
    try {
      await updateTenantProduct(tenantId, editModalProduct.id, {
        ...editForm,
        buyingPrice: Number(editForm.buyingPrice),
        sellingPrice: Number(editForm.sellingPrice),
      });
      setProducts(
        products.map((p) =>
          p.id === editModalProduct.id ? { ...p, ...editForm } : p
        )
      );
      setEditModalProduct(null);
      onNotification?.(`Updated product "${editForm.name}".`);
    } catch (err) {
      onNotification?.(
        `Failed to update product: ${err.message || 'Please try again'}`
      );
    } finally {
      setSavingEdit(false);
    }
  };

  const openStockModal = (product) => {
    setStockModalProduct(product);
    setNewStockQty(String(product.stockQuantity ?? product.onHand ?? 0));
    setStockReason('Platform Operator Inventory Correction');
  };

  const handleSaveStock = async (e) => {
    if (e) e.preventDefault();
    if (!stockModalProduct) return;
    setSavingStock(true);
    try {
      await adjustTenantStock(
        tenantId,
        stockModalProduct.id,
        Number(newStockQty),
        stockReason
      );
      setProducts(
        products.map((p) =>
          p.id === stockModalProduct.id
            ? {
                ...p,
                stockQuantity: Number(newStockQty),
                onHand: Number(newStockQty),
              }
            : p
        )
      );
      setStockModalProduct(null);
      onNotification?.(
        `Adjusted stock for "${stockModalProduct.name}" to ${newStockQty}.`
      );
    } catch (err) {
      onNotification?.(
        `Failed to adjust stock: ${err.message || 'Please try again'}`
      );
    } finally {
      setSavingStock(false);
    }
  };

  const handleSeedStarterPack = async (templateType) => {
    setSeedingLoading(true);
    try {
      await seedStarterCatalog(tenantId, templateType);
      setStarterPackModal(false);
      onNotification?.(
        `Seeded ${templateType} starter catalog into ${tenantName || 'tenant'}.`
      );
      fetchProducts();
    } catch (err) {
      onNotification?.(
        `Failed to seed starter catalog: ${err.message || 'Please try again'}`
      );
    } finally {
      setSeedingLoading(false);
    }
  };

  return (
    <div className="space-y-4">
      {error && (
        <Alert
          type="error"
          title="Could not load product catalog"
          action={
            <Button size="sm" onClick={fetchProducts}>
              Retry
            </Button>
          }
        >
          {error}
        </Alert>
      )}

      <Container
        title="Products"
        count={totalCount}
        description="Inspect and update tenant product catalog, pricing, barcodes, and on-hand stock quantities."
        noPadding
        actions={
          <>
            <Button
              size="sm"
              onClick={() => setStarterPackModal(true)}
            >
              Seed starter catalog
            </Button>
            <Button
              size="sm"
              icon={RefreshCw}
              loading={loading}
              onClick={fetchProducts}
            >
              Refresh
            </Button>
          </>
        }
        footer={
          <div className="flex items-center justify-between text-[12px] text-[#5F6B7A]">
            <span>
              Showing {products.length} of {totalCount} items
            </span>
            <div className="flex items-center gap-1.5">
              <Button
                size="sm"
                icon={ChevronLeft}
                disabled={page <= 1 || loading}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
              >
                Prev
              </Button>
              <span className="px-2 font-medium text-[#16191F]">
                Page {page}
              </span>
              <Button
                size="sm"
                icon={ChevronRight}
                disabled={products.length < 25 || loading}
                onClick={() => setPage((p) => p + 1)}
              >
                Next
              </Button>
            </div>
          </div>
        }
      >
        {/* Filter Bar */}
        <div className="px-4 py-2.5 border-b border-[#E9EBED] bg-white flex flex-col sm:flex-row sm:items-center justify-between gap-2">
          <form
            onSubmit={handleSearchSubmit}
            className="relative flex-1 max-w-md"
          >
            <Search className="w-3.5 h-3.5 text-[#5F6B7A] absolute left-2.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Filter products by name, SKU, or barcode..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-8 pr-3 py-1 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3] focus:ring-1 focus:ring-[#0972D3]"
            />
          </form>

          <div className="flex items-center gap-2">
            <label className="inline-flex items-center gap-1.5 text-[12px] text-[#16191F] cursor-pointer select-none">
              <input
                type="checkbox"
                checked={lowStockOnly}
                onChange={(e) => {
                  setLowStockOnly(e.target.checked);
                  setPage(1);
                }}
                className="rounded-[2px] border-[#879596] text-[#0972D3] focus:ring-[#0972D3]"
              />
              <span>Low stock only</span>
            </label>
          </div>
        </div>

        {/* Dense Cloudscape Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-[#FAFAFA] border-b border-[#E9EBED] text-[11px] font-bold uppercase tracking-wider text-[#5F6B7A]">
                <th className="py-2.5 px-4">SKU / Barcode</th>
                <th className="py-2.5 px-4">Product name</th>
                <th className="py-2.5 px-4">Category</th>
                <th className="py-2.5 px-4 text-right">Cost price</th>
                <th className="py-2.5 px-4 text-right">Selling price</th>
                <th className="py-2.5 px-4 text-right">On hand</th>
                <th className="py-2.5 px-4">Status</th>
                <th className="py-2.5 px-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#E9EBED] text-[13px]">
              {loading ? (
                <tr>
                  <td colSpan={8} className="py-10 text-center text-[#5F6B7A]">
                    <RefreshCw className="w-4 h-4 animate-spin inline mr-2 text-[#0972D3]" />
                    Loading products...
                  </td>
                </tr>
              ) : products.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-10 text-center text-[#5F6B7A]">
                    No products found matching the current filter.
                  </td>
                </tr>
              ) : (
                products.map((product) => {
                  const qty = product.stockQuantity ?? product.onHand ?? 0;
                  const reorder = product.reorderLevel ?? 5;
                  const isLow = qty <= reorder;
                  const buying = product.buyingPrice ?? product.costPrice ?? 0;
                  const selling = product.sellingPrice ?? product.price ?? 0;

                  return (
                    <tr
                      key={product.id}
                      className="hover:bg-[#F1F8FF]/50 transition-colors"
                    >
                      <td className="py-2 px-4 font-mono text-[12px] text-[#5F6B7A]">
                        {product.barcode || product.sku || '—'}
                      </td>
                      <td className="py-2 px-4 font-medium text-[#16191F]">
                        {product.name}
                      </td>
                      <td className="py-2 px-4 text-[#5F6B7A]">
                        <Badge>{product.category || product.categoryName || 'General'}</Badge>
                      </td>
                      <td className="py-2 px-4 text-right tabular-nums text-[#5F6B7A]">
                        {Number(buying).toLocaleString()} {product.currency || 'TZS'}
                      </td>
                      <td className="py-2 px-4 text-right tabular-nums font-semibold text-[#16191F]">
                        {Number(selling).toLocaleString()} {product.currency || 'TZS'}
                      </td>
                      <td className="py-2 px-4 text-right tabular-nums font-semibold">
                        <span className={isLow ? 'text-[#D91515]' : 'text-[#16191F]'}>
                          {qty}
                        </span>{' '}
                        <span className="text-[11px] font-normal text-[#5F6B7A]">
                          {product.unit || 'pcs'}
                        </span>
                      </td>
                      <td className="py-2 px-4">
                        {isLow ? (
                          <StatusIndicator type="warning">Low stock</StatusIndicator>
                        ) : product.isActive === false ? (
                          <StatusIndicator type="pending">Inactive</StatusIndicator>
                        ) : (
                          <StatusIndicator type="success">In stock</StatusIndicator>
                        )}
                      </td>
                      <td className="py-2 px-4 text-right whitespace-nowrap space-x-2">
                        <Button
                          variant="link"
                          size="sm"
                          onClick={() => openStockModal(product)}
                        >
                          Adjust stock
                        </Button>
                        <Button
                          variant="link"
                          size="sm"
                          onClick={() => openEditModal(product)}
                        >
                          Edit
                        </Button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </Container>

      {/* Edit Product Modal */}
      <Modal
        open={Boolean(editModalProduct)}
        onClose={() => setEditModalProduct(null)}
        title={`Edit product — ${editModalProduct?.name || ''}`}
        footer={
          <>
            <Button onClick={() => setEditModalProduct(null)}>Cancel</Button>
            <Button
              variant="primary"
              loading={savingEdit}
              onClick={handleSaveEdit}
            >
              Save changes
            </Button>
          </>
        }
      >
        <form onSubmit={handleSaveEdit} className="space-y-3.5">
          <div>
            <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
              Product name
            </label>
            <input
              type="text"
              required
              value={editForm.name}
              onChange={(e) =>
                setEditForm({ ...editForm, name: e.target.value })
              }
              className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
            />
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                Barcode / SKU
              </label>
              <input
                type="text"
                value={editForm.barcode}
                onChange={(e) =>
                  setEditForm({ ...editForm, barcode: e.target.value })
                }
                className="w-full px-3 py-1.5 text-[13px] font-mono border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
              />
            </div>
            <div>
              <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                Category
              </label>
              <input
                type="text"
                value={editForm.category}
                onChange={(e) =>
                  setEditForm({ ...editForm, category: e.target.value })
                }
                className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
              />
            </div>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                Cost price (TZS)
              </label>
              <input
                type="number"
                value={editForm.buyingPrice}
                onChange={(e) =>
                  setEditForm({ ...editForm, buyingPrice: e.target.value })
                }
                className="w-full px-3 py-1.5 text-[13px] tabular-nums border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
              />
            </div>
            <div>
              <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                Selling price (TZS)
              </label>
              <input
                type="number"
                value={editForm.sellingPrice}
                onChange={(e) =>
                  setEditForm({ ...editForm, sellingPrice: e.target.value })
                }
                className="w-full px-3 py-1.5 text-[13px] tabular-nums border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
              />
            </div>
          </div>
        </form>
      </Modal>

      {/* Adjust Stock Modal */}
      <Modal
        open={Boolean(stockModalProduct)}
        onClose={() => setStockModalProduct(null)}
        title={`Adjust stock — ${stockModalProduct?.name || ''}`}
        size="sm"
        footer={
          <>
            <Button onClick={() => setStockModalProduct(null)}>Cancel</Button>
            <Button
              variant="primary"
              loading={savingStock}
              onClick={handleSaveStock}
            >
              Apply adjustment
            </Button>
          </>
        }
      >
        <form onSubmit={handleSaveStock} className="space-y-3.5">
          <div>
            <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
              New on-hand quantity ({stockModalProduct?.unit || 'pcs'})
            </label>
            <input
              type="number"
              required
              value={newStockQty}
              onChange={(e) => setNewStockQty(e.target.value)}
              className="w-full px-3 py-1.5 text-[14px] font-semibold tabular-nums border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
            />
          </div>
          <div>
            <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
              Audit reason
            </label>
            <input
              type="text"
              required
              value={stockReason}
              onChange={(e) => setStockReason(e.target.value)}
              className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
            />
          </div>
        </form>
      </Modal>

      {/* Seed Starter Catalog Modal */}
      <Modal
        open={starterPackModal}
        onClose={() => setStarterPackModal(false)}
        title="Seed starter catalog"
        size="md"
        footer={
          <Button onClick={() => setStarterPackModal(false)}>Close</Button>
        }
      >
        <div className="space-y-3">
          <p className="text-[13px] text-[#5F6B7A]">
            Populate this tenant workspace with a pre-configured industry product catalog to accelerate onboarding.
          </p>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-2">
            {[
              {
                id: 'duka',
                title: 'Retail & Grocery',
                desc: 'Staple consumer goods, beverages, and household items.',
              },
              {
                id: 'pharmacy',
                title: 'Pharmacy & Medical',
                desc: 'Essential over-the-counter medicines and supplies.',
              },
              {
                id: 'hardware',
                title: 'Hardware & Building',
                desc: 'Cement, tools, fasteners, paint, and plumbing.',
              },
            ].map((tpl) => (
              <div
                key={tpl.id}
                className="border border-[#D5DBDB] rounded-[6px] p-3.5 flex flex-col justify-between bg-[#FAFAFA]"
              >
                <div>
                  <div className="font-bold text-[13px] text-[#16191F]">
                    {tpl.title}
                  </div>
                  <p className="text-[12px] text-[#5F6B7A] mt-1">{tpl.desc}</p>
                </div>
                <div className="mt-3">
                  <Button
                    size="sm"
                    variant="primary"
                    loading={seedingLoading}
                    onClick={() => handleSeedStarterPack(tpl.id)}
                  >
                    Seed {tpl.title}
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </Modal>
    </div>
  );
}
