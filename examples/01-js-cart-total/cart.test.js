import { test } from "node:test";
import assert from "node:assert/strict";
import { cartTotal } from "./cart.js";

test("пустая корзина", () => {
  assert.equal(cartTotal([]), 0);
});

test("сумма без скидки", () => {
  assert.equal(cartTotal([{ price: 100, qty: 2 }, { price: 50.5, qty: 1 }]), 250.5);
});

test("скидка 10% от 5000", () => {
  assert.equal(cartTotal([{ price: 2500, qty: 2 }]), 4500);
});

test("округление до копеек", () => {
  assert.equal(cartTotal([{ price: 3333.33, qty: 2 }]), 5999.99);
});
