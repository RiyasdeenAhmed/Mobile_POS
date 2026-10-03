/// PBKDF2 work factor used by tests.
///
/// Production stays at `defaultIterations` (120000). Tests inject 1000 so
/// widget suites that sign in or change PINs do not spend seconds per call.
/// Verification always reads the iteration count from the encoded hash, so
/// hashes produced here still verify correctly.
const int kTestPinIterations = 1000;
