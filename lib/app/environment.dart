/// Non-operational utilities must be explicitly enabled in development builds.
const developmentToolsEnabled = bool.fromEnvironment(
  'RSA_DEVELOPMENT_TOOLS',
  defaultValue: false,
);
