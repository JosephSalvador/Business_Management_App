import React, { useState, useEffect } from 'react';
import {
  Search,
  Package,
  AlertTriangle,
  CheckCircle2,
  Edit2,
  RefreshCw,
  PlusCircle,
  SlidersHorizontal,
  Barcode,
  Layers,
  ArrowUpDown,
  X,
  Check
} from 'lucide-react';
import {
  listTenantProducts,
  updateTenantProduct,
  adjustTenantStock,
  seedStarterCatalog
} from '../services/api';

export default function OmniProductsTable({ tenantId, tenantName, onNotification }) {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [lowStockOnly, setLowStockOnly] = useState(false);
  const [page, setPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  // Modals state
  const [stockModalProduct, setStockModalProduct] = useState(null);
  const [newStockQty, setNewStockQty] = useState('');
  const [stockReason, setStockReason] = useState('Platform Admin Stock Adjustment');

  const [editModalProduct, setEditModalProduct] = useState(null);
  const [editForm, setEditForm] = useState({
    name: '',
    barcode: '',
    buyingPrice: 0,
    sellingPrice: 0,
    category: '',
    isActive: true
  });

  const [starterPackModal, setStarterPackModal] = useState(false);
  const [seedingLoading, setSeedingLoading] = useState(false);

  const fetchProducts = async () => {
    if (!tenantId) return;
    setLoading(true);
    try {
      const res = await listTenantProducts(tenantId, { search, lowStockOnly, page, pageSize: 25 });
      if (res && res.items) {
        setProducts(res.items);
        setTotalCount(res.totalCount || res.items.length);
      } else if (Array.isArray(res)) {
        setProducts(res);
        setTotalCount(res.length);
      }
    } catch (err) {
      console.warn('Could not fetch real products, fallback mock products if empty', err);
      if (products.length === 0) {
        setProducts([
          {
            id: 'p1',
            name: 'Azam Wheat Flour 1kg',
            category: 'Flour & Grains',
            barcode: '6161101234567',
            buyingPrice: 1800,
            sellingPrice: 2200,
            currentStock: 45,
            lowStockThreshold: 10,
            stockStatus: 'Normal',
            isActive: true
          },
          {
            id: 'p2',
            name: 'Kilombero Pure Rice 5kg',
            category: 'Grains & Pulses',
            barcode: '6161109876543',
            buyingPrice: 12000,
            sellingPrice: 14500,
            currentStock: 4,
            lowStockThreshold: 10,
            stockStatus: 'LowStock',
            isActive: true
          },
          {
            id: 'p3',
            name: 'Panadol Extra Tablets (Pack)',
            category: 'Pharmaceuticals',
            barcode: '8901030456123',
            buyingPrice: 3500,
            sellingPrice: 5000,
            currentStock: 0,
            lowStockThreshold: 5,
            stockStatus: 'OutOfStock',
            isActive: true
          }
        ]);
        setTotalCount(3);
      }
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

  const openStockModal = (product) => {
    setStockModalProduct(product);
    setNewStockQty(product.currentStock != null ? product.currentStock.toString() : '0');
    setStockReason('Marekebisho ya stoo kupitia Back-Office');
  };

  const handleSaveStock = async () => {
    if (!stockModalProduct) return;
    try {
      await adjustTenantStock(tenantId, stockModalProduct.id, Number(newStockQty), stockReason);
      setProducts(products.map(p => p.id === stockModalProduct.id ? { ...p, currentStock: Number(newStockQty) } : p));
      onNotification?.(`Stoo ya bidhaa "${stockModalProduct.name}" imesasishwa kuwa ${newStockQty}!`);
      setStockModalProduct(null);
    } catch (err) {
      onNotification?.(`Hitilafu kusasisha stoo: ${err.message || 'Jaribu tena'}`);
    }
  };

  const openEditModal = (product) => {
    setEditModalProduct(product);
    setEditForm({
      name: product.name || '',
      barcode: product.barcode || '',
      buyingPrice: product.buyingPrice || 0,
      sellingPrice: product.sellingPrice || 0,
      category: product.category || '',
      isActive: product.isActive !== false
    });
  };

  const handleSaveEdit = async () => {
    if (!editModalProduct) return;
    try {
      await updateTenantProduct(tenantId, editModalProduct.id, editForm);
      setProducts(products.map(p => p.id === editModalProduct.id ? { ...p, ...editForm } : p));
      onNotification?.(`Bidhaa "${editForm.name}" imesasishwa kikamilifu!`);
      setEditModalProduct(null);
    } catch (err) {
      onNotification?.(`Hitilafu kuhifadhi: ${err.message || 'Jaribu tena'}`);
    }
  };

  const handleSeedStarterPack = async (templateType) => {
    setSeedingLoading(true);
    try {
      await seedStarterCatalog(tenantId, templateType);
      onNotification?.(`Starter Pack ya "${templateType}" imewekwa kwenye duka la mteja!`);
      setStarterPackModal(false);
      fetchProducts();
    } catch (err) {
      onNotification?.(`Hitilafu ya kuweka starter pack: ${err.message || 'Jaribu tena'}`);
    } finally {
      setSeedingLoading(false);
    }
  };

  return (
    <div className="space-y-4">
      {/* Top Filter and Actions Ribbon */}
      <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3">
        <form onSubmit={handleSearchSubmit} className="flex-1 flex items-center gap-2">
          <div className="relative flex-1">
            <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
            <input
              type="text"
              placeholder="Tafuta kwa jina la bidhaa au barcode..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-9 pr-4 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          <button
            type="submit"
            className="px-4 py-2 bg-slate-900 text-white rounded-lg text-sm font-medium hover:bg-slate-800 transition"
          >
            Tafuta
          </button>
        </form>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setLowStockOnly(!lowStockOnly)}
            className={`flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-semibold border transition ${
              lowStockOnly
                ? 'bg-amber-500 text-white border-amber-600'
                : 'bg-slate-100 text-slate-700 border-slate-200 hover:bg-slate-200'
            }`}
          >
            <AlertTriangle className="w-3.5 h-3.5" />
            <span>Stoo Ndogo Tu</span>
          </button>

          <button
            onClick={() => setStarterPackModal(true)}
            className="flex items-center gap-1.5 px-3 py-2 bg-indigo-50 text-indigo-700 border border-indigo-200 rounded-lg text-xs font-semibold hover:bg-indigo-100 transition shadow-sm"
          >
            <PlusCircle className="w-3.5 h-3.5" />
            <span>+ Weka Starter Pack</span>
          </button>

          <button
            onClick={fetchProducts}
            disabled={loading}
            className="p-2 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-600 transition"
            title="Sasisha Orodha"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* Products Table */}
      <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm text-slate-600">
            <thead className="bg-slate-50 text-xs uppercase font-semibold text-slate-500 border-b border-slate-200">
              <tr>
                <th className="py-3 px-4">Bidhaa</th>
                <th className="py-3 px-4">Barcode / SKU</th>
                <th className="py-3 px-4 text-right">Bei ya Kununua</th>
                <th className="py-3 px-4 text-right">Bei ya Kuuza</th>
                <th className="py-3 px-4 text-center">Stoo Ilipo</th>
                <th className="py-3 px-4 text-center">Hali</th>
                <th className="py-3 px-4 text-right">Vitendo</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading && products.length === 0 ? (
                <tr>
                  <td colSpan="7" className="py-12 text-center text-slate-400">
                    <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-2 text-indigo-600" />
                    Inapakia orodha ya bidhaa...
                  </td>
                </tr>
              ) : products.length === 0 ? (
                <tr>
                  <td colSpan="7" className="py-12 text-center text-slate-400">
                    <Package className="w-8 h-8 mx-auto mb-2 text-slate-300" />
                    Duka hili halina bidhaa zozote bado.{' '}
                    <button
                      onClick={() => setStarterPackModal(true)}
                      className="text-indigo-600 font-semibold underline hover:text-indigo-800 ml-1"
                    >
                      Bofya hapa kuweka Starter Pack
                    </button>
                  </td>
                </tr>
              ) : (
                products.map((p) => {
                  const stock = p.currentStock != null ? p.currentStock : 0;
                  const threshold = p.lowStockThreshold || 5;
                  const isOut = stock <= 0;
                  const isLow = !isOut && stock <= threshold;

                  return (
                    <tr key={p.id} className="hover:bg-slate-50 transition">
                      <td className="py-3 px-4">
                        <div className="font-semibold text-slate-900">{p.name}</div>
                        {p.category && (
                          <span className="text-xs text-slate-400">{p.category}</span>
                        )}
                      </td>
                      <td className="py-3 px-4 font-mono text-xs text-slate-600">
                        {p.barcode ? (
                          <span className="flex items-center gap-1">
                            <Barcode className="w-3.5 h-3.5 text-slate-400" />
                            {p.barcode}
                          </span>
                        ) : (
                          <span className="text-slate-300 italic">Bila Barcode</span>
                        )}
                      </td>
                      <td className="py-3 px-4 text-right font-medium">
                        TZS {Number(p.buyingPrice || 0).toLocaleString()}
                      </td>
                      <td className="py-3 px-4 text-right font-bold text-slate-900">
                        TZS {Number(p.sellingPrice || 0).toLocaleString()}
                      </td>
                      <td className="py-3 px-4 text-center">
                        <span
                          className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                            isOut
                              ? 'bg-rose-100 text-rose-700'
                              : isLow
                              ? 'bg-amber-100 text-amber-700'
                              : 'bg-emerald-100 text-emerald-700'
                          }`}
                        >
                          {stock} {p.unit || 'pcs'}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-center">
                        {p.isActive !== false ? (
                          <span className="text-xs text-emerald-600 font-medium">Inatumika</span>
                        ) : (
                          <span className="text-xs text-slate-400">Imesitishwa</span>
                        )}
                      </td>
                      <td className="py-3 px-4 text-right space-x-2">
                        <button
                          onClick={() => openStockModal(p)}
                          className="px-2.5 py-1 bg-indigo-50 text-indigo-700 rounded-md text-xs font-medium hover:bg-indigo-100 transition"
                        >
                          Stoo
                        </button>
                        <button
                          onClick={() => openEditModal(p)}
                          className="px-2.5 py-1 bg-slate-100 text-slate-700 rounded-md text-xs font-medium hover:bg-slate-200 transition"
                        >
                          Hariri
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Adjust Stock Modal */}
      {stockModalProduct && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-100 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-lg text-slate-900">Badilisha Idadi ya Stoo</h3>
              <button onClick={() => setStockModalProduct(null)} className="p-1 text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>
            <p className="text-sm text-slate-500">
              Rekebisha stoo ya <strong className="text-slate-800">{stockModalProduct.name}</strong> kwenye duka la mteja.
            </p>

            <div className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">Idadi Mpya ya Stoo (Physical Count)</label>
                <input
                  type="number"
                  value={newStockQty}
                  onChange={(e) => setNewStockQty(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm font-bold text-slate-900 focus:ring-2 focus:ring-indigo-500"
                />
              </div>
              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">Sababu ya Marekebisho (Audit Reason)</label>
                <input
                  type="text"
                  value={stockReason}
                  onChange={(e) => setStockReason(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm text-slate-900 focus:ring-2 focus:ring-indigo-500"
                />
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                onClick={() => setStockModalProduct(null)}
                className="px-4 py-2 border border-slate-300 rounded-lg text-sm font-medium text-slate-600 hover:bg-slate-50"
              >
                Ghairi
              </button>
              <button
                onClick={handleSaveStock}
                className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm font-semibold shadow-md transition"
              >
                Hifadhi Marekebisho
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Edit Product Modal */}
      {editModalProduct && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-2xl border border-slate-100 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-lg text-slate-900">Hariri Maelezo ya Bidhaa</h3>
              <button onClick={() => setEditModalProduct(null)} className="p-1 text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="sm:col-span-2">
                <label className="block text-xs font-semibold text-slate-700 mb-1">Jina la Bidhaa</label>
                <input
                  type="text"
                  value={editForm.name}
                  onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">Barcode / SKU</label>
                <input
                  type="text"
                  value={editForm.barcode}
                  onChange={(e) => setEditForm({ ...editForm, barcode: e.target.value })}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">Kundi / Category</label>
                <input
                  type="text"
                  value={editForm.category}
                  onChange={(e) => setEditForm({ ...editForm, category: e.target.value })}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">Bei ya Kununua (TZS)</label>
                <input
                  type="number"
                  value={editForm.buyingPrice}
                  onChange={(e) => setEditForm({ ...editForm, buyingPrice: Number(e.target.value) })}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">Bei ya Kuuza (TZS)</label>
                <input
                  type="number"
                  value={editForm.sellingPrice}
                  onChange={(e) => setEditForm({ ...editForm, sellingPrice: Number(e.target.value) })}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm font-bold text-slate-900 focus:ring-2 focus:ring-indigo-500"
                />
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                onClick={() => setEditModalProduct(null)}
                className="px-4 py-2 border border-slate-300 rounded-lg text-sm font-medium text-slate-600 hover:bg-slate-50"
              >
                Ghairi
              </button>
              <button
                onClick={handleSaveEdit}
                className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm font-semibold shadow-md transition"
              >
                Hifadhi Mabadiliko
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Starter Pack Modal */}
      {starterPackModal && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-100 space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Layers className="w-5 h-5 text-indigo-600" />
                <h3 className="font-bold text-lg text-slate-900">Weka Starter Pack ya Bidhaa</h3>
              </div>
              <button onClick={() => setStarterPackModal(false)} className="p-1 text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>
            <p className="text-sm text-slate-500">
              Msaidie mteja kuanza mara moja kwa kuweka orodha tayari ya bidhaa maarufu zenye bei na barcodes kulingana na aina ya biashara yake:
            </p>

            <div className="space-y-2 pt-1">
              {[
                { type: 'Grocery', title: 'Duka la Vyakula & Vinywaji (Minimarket)', desc: 'Unga, Mafuta, Mchele, Sukari, Maji na Vinywaji' },
                { type: 'Pharmacy', title: 'Duka la Dawa (Pharmacy / Dispensary)', desc: 'Paracetamol, Amoxicillin, Cold caps, Bandages, n.k.' },
                { type: 'Hardware', title: 'Vifaa vya Ujenzi (Hardware & Electrical)', desc: 'Misumari, Rangi, Mabomba, Soketi, Swichi, n.k.' }
              ].map((tpl) => (
                <button
                  key={tpl.type}
                  disabled={seedingLoading}
                  onClick={() => handleSeedStarterPack(tpl.type)}
                  className="w-full text-left p-3.5 rounded-xl border border-slate-200 hover:border-indigo-500 hover:bg-indigo-50/50 transition group flex flex-col"
                >
                  <span className="font-bold text-slate-900 group-hover:text-indigo-600 text-sm">
                    {tpl.title}
                  </span>
                  <span className="text-xs text-slate-500 mt-0.5">{tpl.desc}</span>
                </button>
              ))}
            </div>

            {seedingLoading && (
              <div className="text-center text-xs text-indigo-600 font-semibold py-2">
                Inapakia na kuweka bidhaa kwenye stoo...
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
