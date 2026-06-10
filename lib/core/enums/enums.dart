/// All enums used across the app
library;

/// User roles in the system
enum UserRole {
  admin('admin', 'Admin'),
  partner('partner', 'Partner'),
  buyer('buyer', 'Buyer'),
  platformAdmin('platform_admin', 'Platform Admin');

  const UserRole(this.value, this.label);
  final String value;
  final String label;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.buyer,
    );
  }
}

/// Property listing status
enum PropertyStatus {
  available('available', 'Available'),
  reserved('reserved', 'Reserved'),
  sold('sold', 'Sold');

  const PropertyStatus(this.value, this.label);
  final String value;
  final String label;

  static PropertyStatus fromString(String value) {
    return PropertyStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => PropertyStatus.available,
    );
  }
}

/// Lead pipeline stages
enum LeadStage {
  newLead('new', 'New'),
  contacted('contacted', 'Contacted'),
  inspectionBooked('inspection_booked', 'Inspection Booked'),
  negotiation('negotiation', 'Negotiation'),
  closed('closed', 'Closed'),
  lost('lost', 'Lost');

  const LeadStage(this.value, this.label);
  final String value;
  final String label;

  static LeadStage fromString(String value) {
    return LeadStage.values.firstWhere(
      (s) => s.value == value,
      orElse: () => LeadStage.newLead,
    );
  }
}

/// Commission status
enum CommissionStatus {
  pending('pending', 'Pending'),
  approved('approved', 'Approved'),
  paid('paid', 'Paid'),
  disputed('disputed', 'Disputed');

  const CommissionStatus(this.value, this.label);
  final String value;
  final String label;

  static CommissionStatus fromString(String value) {
    return CommissionStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => CommissionStatus.pending,
    );
  }
}

/// Inspection status
enum InspectionStatus {
  pending('pending', 'Pending'),
  confirmed('confirmed', 'Confirmed'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled'),
  noShow('no_show', 'No Show');

  const InspectionStatus(this.value, this.label);
  final String value;
  final String label;

  static InspectionStatus fromString(String value) {
    return InspectionStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => InspectionStatus.pending,
    );
  }
}

/// Partner account status
enum PartnerStatus {
  pending('pending', 'Pending'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  suspended('suspended', 'Suspended');

  const PartnerStatus(this.value, this.label);
  final String value;
  final String label;

  static PartnerStatus fromString(String value) {
    return PartnerStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => PartnerStatus.pending,
    );
  }
}

/// Transaction types
enum TransactionType {
  credit('credit', 'Credit'),
  debit('debit', 'Debit'),
  withdrawal('withdrawal', 'Withdrawal');

  const TransactionType(this.value, this.label);
  final String value;
  final String label;

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (s) => s.value == value,
      orElse: () => TransactionType.credit,
    );
  }
}

/// Commission calculation type
enum CommissionType {
  percentage('percentage', 'Percentage'),
  flatFee('flat_fee', 'Flat Fee');

  const CommissionType(this.value, this.label);
  final String value;
  final String label;

  static CommissionType fromString(String value) {
    return CommissionType.values.firstWhere(
      (s) => s.value == value,
      orElse: () => CommissionType.percentage,
    );
  }
}
