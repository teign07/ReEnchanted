import {
  minimumProductPriceCentsPerCopy,
  priceBreakdown,
} from "./lulu-quote-worker.mjs";

const softcover = {
  id: "perfect-bound-softcover-6x9",
  coverTreatment: "perfectBound",
  manufacturingBasePriceCentsUSD: 320,
  manufacturingPerPagePriceTenThousandthsUSD: 425,
};
const cloth = {
  id: "cloth-foil-hardcover-6x9",
  coverTreatment: "linenWrap",
  manufacturingBasePriceCentsUSD: 1441,
  manufacturingPerPagePriceTenThousandthsUSD: 425,
};

function request(editionKind) {
  return {
    editionID: editionKind === "monthly" ? "2026-08" : "2026-06-through-2026-08",
    editionKind,
    variant: softcover,
    pageCount: 96,
    quantity: 1,
    currencyCode: "USD",
    selectedOptionIDs: [],
  };
}

function check(condition, message) {
  if (!condition) throw new Error(message);
  console.log(`✓ ${message}`);
}

const monthly = priceBreakdown(request("monthly"), 0);
const seasonal = priceBreakdown(request("seasonal"), 0);

check(monthly.manufacturingSubtotal.cents === 728, "96-page softcover manufacturing is $7.28");
check(monthly.manufacturingSubtotal.cents + monthly.markup.cents === 4999, "monthly softcover product price is $49.99");
check(seasonal.manufacturingSubtotal.cents + seasonal.markup.cents === 6999, "seasonal softcover product price is $69.99");
check(monthly.markup.cents === 4271, "monthly softcover contributes $42.71 before overhead");
check(seasonal.markup.cents === 6271, "seasonal softcover contributes $62.71 before overhead");
check(minimumProductPriceCentsPerCopy(softcover) === 7999, "legacy softcover quotes retain the $79.99 floor");

const separateSet = minimumProductPriceCentsPerCopy(softcover, "seasonal") * 3
  + minimumProductPriceCentsPerCopy(cloth, "annual");
check(separateSet === 30996, "three seasonal softcovers and annual cloth book total $309.96");
check(separateSet > 2499 * 12, "monthly Bound Year remains cheaper than four separate books");
check(separateSet > 24900, "annual Bound Year remains cheaper than four separate books");
