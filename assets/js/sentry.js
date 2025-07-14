import * as Sentry from "@sentry/browser";

Sentry.init({
  dsn: document.querySelector("meta[name=sentry-dsn]").getAttribute("content"),
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1,
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration({
      maskAllText: false,
      blockAllMedia: false,
    }),
  ],
  tracesSampleRate: 1.0,
});
