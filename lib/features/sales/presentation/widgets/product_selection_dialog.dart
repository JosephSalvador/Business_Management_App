import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/sale_models.dart';

class Product {
  final String id;
  final String name;
  final String code;
  final double price;
  final String category;
  final int stock;
  final String image;

  Product({
    required this.id,
    required this.name,
    required this.code,
    required this.price,
    required this.category,
    required this.stock,
    required this.image,
  });
}

class ProductSelectionDialog extends StatefulWidget {
  final Function(SaleItem) onProductSelected;

  const ProductSelectionDialog({super.key, required this.onProductSelected});

  @override
  State<ProductSelectionDialog> createState() => _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<ProductSelectionDialog> {
  final List<Product> _products = [
    Product(
      id: '1',
      name: 'MacBook Pro 16"',
      code: 'LP-DELL-XPS15',
      price: 2500000.00,
      category: 'Electronics',
      stock: 15,
      image: '💻',
    ),
    Product(
      id: '2',
      name: 'Wireless Mouse',
      code: 'ACC-MOUSE-WL',
      price: 45000.00,
      category: 'Accessories',
      stock: 100,
      image: '🖱️',
    ),
    Product(
      id: '3',
      name: 'Mechanical Keyboard',
      code: 'ACC-KEY-MECH',
      price: 120000.00,
      category: 'Accessories',
      stock: 25,
      image: '⌨️',
    ),
    Product(
      id: '4',
      name: '4K Monitor',
      code: 'MON-4K-27',
      price: 850000.00,
      category: 'Electronics',
      stock: 30,
      image: '🖥️',
    ),
    Product(
      id: '5',
      name: 'Office Chair',
      code: 'FURN-CHAIR-EX',
      price: 180000.00,
      category: 'Furniture',
      stock: 10,
      image: '💺',
    ),
  ];

  final Map<String, int> _selectedQuantities = {};

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AppBar(
            title: Text(
              'Select Products',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                final quantity = _selectedQuantities[product.id] ?? 0;
                
                return _ProductItem(
                  product: product,
                  quantity: quantity,
                  onQuantityChanged: (newQuantity) {
                    setState(() {
                      if (newQuantity > 0) {
                        _selectedQuantities[product.id] = newQuantity;
                      } else {
                        _selectedQuantities.remove(product.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Text(
                  'Selected: ${_selectedQuantities.length} items',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectedQuantities.isNotEmpty ? _addSelectedProducts : null,
                  child: const Text('Add to Sale'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addSelectedProducts() {
    for (final entry in _selectedQuantities.entries) {
      final product = _products.firstWhere((p) => p.id == entry.key);
      final quantity = entry.value;

      final saleItem = SaleItem(
        id: product.id,
        productName: product.name,
        productCode: product.code,
        quantity: quantity,
        unitPrice: product.price,
        vatRate: 18.0, // Will be recalculated based on payment method
        vatAmount: (product.price * quantity * 18) / 118,
        totalAmount: product.price * quantity,
      );

      widget.onProductSelected(saleItem);
    }

    Navigator.pop(context);
  }
}

class _ProductItem extends StatelessWidget {
  final Product product;
  final int quantity;
  final Function(int) onQuantityChanged;

  const _ProductItem({
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Product Image/Emoji
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  product.image,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    product.code,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TZS ${_formatCurrency(product.price)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Stock: ${product.stock}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Quantity Controls
            Column(
              children: [
                if (quantity == 0)
                  ElevatedButton(
                    onPressed: () => onQuantityChanged(1),
                    child: const Text('Add'),
                  )
                else
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: () => onQuantityChanged(quantity - 1),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          quantity.toString(),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () => onQuantityChanged(quantity + 1),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}