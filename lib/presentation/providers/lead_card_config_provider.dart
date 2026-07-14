import 'package:flutter_riverpod/legacy.dart';

class LeadCardConfig {
  final bool showContact;
  final bool showDOB;
  final bool showProject;
  final bool showProperty;
  final bool showService;
  final bool showAmount;
  final bool showSource;
  final bool showReferredBy;
  final bool showStatus;
  final bool showStage;
  final bool showAssignedTo;
  final bool showTeam;
  final bool showGroup;
  final bool showTimeline;
  final bool showDestination;
  final bool showTravelStartDate;
  final bool showTravelEndDate;

  const LeadCardConfig({
    this.showContact = true,
    this.showDOB = true,
    this.showProject = true,
    this.showProperty = true,
    this.showService = true,
    this.showAmount = true,
    this.showSource = true,
    this.showReferredBy = true,
    this.showStatus = true,
    this.showStage = true,
    this.showAssignedTo = false,
    this.showTeam = false,
    this.showGroup = false,
    this.showTimeline = false,
    this.showDestination = true,
    this.showTravelStartDate = true,
    this.showTravelEndDate = true,
  });

  LeadCardConfig copyWith({
    bool? showContact,
    bool? showDOB,
    bool? showProject,
    bool? showProperty,
    bool? showService,
    bool? showAmount,
    bool? showSource,
    bool? showReferredBy,
    bool? showStatus,
    bool? showStage,
    bool? showAssignedTo,
    bool? showTeam,
    bool? showGroup,
    bool? showTimeline,
    bool? showDestination,
    bool? showTravelStartDate,
    bool? showTravelEndDate,
  }) {
    return LeadCardConfig(
      showContact: showContact ?? this.showContact,
      showDOB: showDOB ?? this.showDOB,
      showProject: showProject ?? this.showProject,
      showProperty: showProperty ?? this.showProperty,
      showService: showService ?? this.showService,
      showAmount: showAmount ?? this.showAmount,
      showSource: showSource ?? this.showSource,
      showReferredBy: showReferredBy ?? this.showReferredBy,
      showStatus: showStatus ?? this.showStatus,
      showStage: showStage ?? this.showStage,
      showAssignedTo: showAssignedTo ?? this.showAssignedTo,
      showTeam: showTeam ?? this.showTeam,
      showGroup: showGroup ?? this.showGroup,
      showTimeline: showTimeline ?? this.showTimeline,
      showDestination: showDestination ?? this.showDestination,
      showTravelStartDate: showTravelStartDate ?? this.showTravelStartDate,
      showTravelEndDate: showTravelEndDate ?? this.showTravelEndDate,
    );
  }
}

class LeadCardConfigNotifier extends StateNotifier<LeadCardConfig> {
  LeadCardConfigNotifier() : super(const LeadCardConfig());

  void toggleContact(bool value) => state = state.copyWith(showContact: value);
  void toggleDOB(bool value) => state = state.copyWith(showDOB: value);
  void toggleProject(bool value) => state = state.copyWith(showProject: value);
  void toggleProperty(bool value) => state = state.copyWith(showProperty: value);
  void toggleService(bool value) => state = state.copyWith(showService: value);
  void toggleAmount(bool value) => state = state.copyWith(showAmount: value);
  void toggleSource(bool value) => state = state.copyWith(showSource: value);
  void toggleReferredBy(bool value) => state = state.copyWith(showReferredBy: value);
  void toggleStatus(bool value) => state = state.copyWith(showStatus: value);
  void toggleStage(bool value) => state = state.copyWith(showStage: value);
  void toggleAssignedTo(bool value) => state = state.copyWith(showAssignedTo: value);
  void toggleTeam(bool value) => state = state.copyWith(showTeam: value);
  void toggleGroup(bool value) => state = state.copyWith(showGroup: value);
  void toggleTimeline(bool value) => state = state.copyWith(showTimeline: value);
  void toggleDestination(bool value) => state = state.copyWith(showDestination: value);
  void toggleTravelStartDate(bool value) => state = state.copyWith(showTravelStartDate: value);
  void toggleTravelEndDate(bool value) => state = state.copyWith(showTravelEndDate: value);
  
  void resetToDefault() => state = const LeadCardConfig();
}

final leadCardConfigProvider = StateNotifierProvider<LeadCardConfigNotifier, LeadCardConfig>((ref) {
  return LeadCardConfigNotifier();
});
