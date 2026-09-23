import { test } from "node:test";
import assert from "node:assert/strict";
import { withRetry } from "./retry.js";

test("повторяет до успеха", async () => {
  let calls = 0;
  const flaky = withRetry(async () => {
    calls++;
    if (calls < 3) throw new Error("fail");
    return "ok";
  }, { baseDelay: 1 });
  assert.equal(await flaky(), "ok");
  assert.equal(calls, 3);
});

test("не повторяет, если shouldRetry вернул false", async () => {
  let calls = 0;
  const fn = withRetry(async () => {
    calls++;
    throw new Error("fatal");
  }, { baseDelay: 1, shouldRetry: () => false });
  await assert.rejects(fn(), /fatal/);
  assert.equal(calls, 1);
});
