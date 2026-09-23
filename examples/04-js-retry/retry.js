const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export function withRetry(fn, { attempts = 3, baseDelay = 100, shouldRetry = () => true } = {}) {
  return async function retried(...args) {
    let lastError;
    for (let attempt = 1; attempt <= attempts; attempt++) {
      try {
        return await fn.apply(this, args);
      } catch (error) {
        lastError = error;
        if (attempt === attempts || !shouldRetry(error)) break;
        const delay = baseDelay * 2 ** (attempt - 1);
        await sleep(delay + Math.random() * delay * 0.1);
      }
    }
    throw lastError;
  };
}
