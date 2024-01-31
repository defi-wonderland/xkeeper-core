/** @type {import('@defi-wonderland/natspec-smells').Config} */
module.exports = {
  include: "solidity",
  exclude: [
    "solidity/(test|script)/**/*.sol",
    "solidity/interfaces/external/**/*.sol",
  ],
};
