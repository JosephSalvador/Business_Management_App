
class SavedPrinter {
  final String id;
  final String name;
  final String address;
  final DateTime lastConnected;
  final bool isConnected;

  SavedPrinter({
    required this.id,
    required this.name,
    required this.address,
    required this.lastConnected,
    this.isConnected = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'lastConnected': lastConnected.toIso8601String(),
      'isConnected': isConnected,
    };
  }

  factory SavedPrinter.fromJson(Map<String, dynamic> json) {
    return SavedPrinter(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      lastConnected: DateTime.parse(json['lastConnected']),
      isConnected: json['isConnected'] ?? false,
    );
  }

  SavedPrinter copyWith({
    String? id,
    String? name,
    String? address,
    DateTime? lastConnected,
    bool? isConnected,
  }) {
    return SavedPrinter(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      lastConnected: lastConnected ?? this.lastConnected,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}