import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/app/coordinators/login_data_coordinator.dart';

void main() {
  group('LoginDataCoordinator', () {
    test('prepareOnline clears cache and force refreshes all modules', () async {
      var clearCalled = false;
      var gradesForceRefresh = false;
      var scheduleForceRefresh = false;
      var progressForceRefresh = false;
      var examForceRefresh = false;

      await LoginDataCoordinator.prepareOnline(
        clearCache: () async {
          clearCalled = true;
        },
        loadGrades: ({bool forceRefresh = false}) async {
          if (forceRefresh) gradesForceRefresh = true;
        },
        loadSchedule: ({bool forceRefresh = false}) async {
          if (forceRefresh) scheduleForceRefresh = true;
        },
        loadProgress: ({bool forceRefresh = false}) async {
          if (forceRefresh) progressForceRefresh = true;
        },
        loadExamSemesters: ({bool forceRefresh = false}) async {
          if (forceRefresh) examForceRefresh = true;
        },
      );

      expect(clearCalled, isTrue);
      expect(gradesForceRefresh, isTrue);
      expect(scheduleForceRefresh, isTrue);
      expect(progressForceRefresh, isTrue);
      expect(examForceRefresh, isTrue);
    });

    test('prepareOffline loads all modules without force refresh', () async {
      var gradesForceRefresh = true;
      var scheduleForceRefresh = true;
      var progressForceRefresh = true;
      var examForceRefresh = true;

      LoginDataCoordinator.prepareOffline(
        loadGrades: ({bool forceRefresh = false}) async {
          gradesForceRefresh = forceRefresh;
        },
        loadSchedule: ({bool forceRefresh = false}) async {
          scheduleForceRefresh = forceRefresh;
        },
        loadProgress: ({bool forceRefresh = false}) async {
          progressForceRefresh = forceRefresh;
        },
        loadExamSemesters: ({bool forceRefresh = false}) async {
          examForceRefresh = forceRefresh;
        },
      );

      await Future<void>.delayed(Duration.zero);

      expect(gradesForceRefresh, isFalse);
      expect(scheduleForceRefresh, isFalse);
      expect(progressForceRefresh, isFalse);
      expect(examForceRefresh, isFalse);
    });
  });
}
