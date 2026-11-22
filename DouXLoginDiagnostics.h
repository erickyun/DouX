#import <UIKit/UIKit.h>

// Privacy-safe local diagnostics. No URLs, login credentials, cookies or tokens
// are retained. The report is shared only if the user copies it.
FOUNDATION_EXPORT void DouXLoginDiagnosticsShow(void);
FOUNDATION_EXPORT void DouXLoginDiagnosticsRecord(NSString *event);
FOUNDATION_EXPORT NSString *DouXLoginEnvironmentReport(void);
FOUNDATION_EXPORT NSString *DouXLoginAssessment(NSArray<NSString *> *events);
FOUNDATION_EXPORT NSString *DouXLoginSelfCheckResult(void);
FOUNDATION_EXPORT void DouXLoginRunFullCheck(void);
