/// Business identity snapshot captured at sale time. Contains the exact business
/// details (name, TIN, address) that were in effect when the receipt was issued.
library;

/// A frozen snapshot of the business identity at sale time.
class BusinessIdentity {
  const BusinessIdentity({
    required this.businessName,
    this.tin,
    this.address,
    this.phone,
    this.email,
  });

  factory BusinessIdentity.fromJson(Map<String, dynamic> json) =>
      BusinessIdentity(
        businessName: json['businessName'] as String,
        tin: json['tin'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
      );

  final String businessName;
  final String? tin;
  final String? address;
  final String? phone;
  final String? email;

  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        if (tin != null) 'tin': tin,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
      };
}
