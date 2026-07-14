class RoleLabelsModel {
  final String companyAdmin;
  final String salesManager;
  final String teamLeader;
  final String salesExecutive;

  RoleLabelsModel({
    required this.companyAdmin,
    required this.salesManager,
    required this.teamLeader,
    required this.salesExecutive,
  });

  factory RoleLabelsModel.fromJson(Map<String, dynamic> json) {
    return RoleLabelsModel(
      companyAdmin: json['company_admin'] ?? 'Company Admin',
      salesManager: json['sales_manager'] ?? 'Sales Manager',
      teamLeader: json['team_leader'] ?? 'Team Leader',
      salesExecutive: json['sales_executive'] ?? 'Sales Executive',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_admin': companyAdmin,
      'sales_manager': salesManager,
      'team_leader': teamLeader,
      'sales_executive': salesExecutive,
    };
  }
}
