import * as Sentry from "https://esm.sh/@sentry/browser@9.35.0";

Sentry.init({
  dsn: document.querySelector("meta[name=sentry-dsn]").getAttribute("content"),
  integrations: [Sentry.browserTracingIntegration()],
  tracesSampleRate: 1.0,
});
