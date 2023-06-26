require("dotenv").config();

const { string } = require("hardhat/internal/core/params/argumentTypes");
const {
  getRole,
  verify,
  ex,
  printAddress,
  deploySC,
  deploySCNoUp,
} = require("../utils");

var MINTER_ROLE = getRole("MINTER_ROLE");
var BURNER_ROLE = getRole("BURNER_ROLE");

async function deployMumbai() {
  var relayerAddress = "0xfcB8555bB06b13784E7861ddC9587B9920AF8026";

var nftContract = await deploySC("MiPrimerNft", []);
var implementation = await printAddress("MiPrimerNft", nftContract.address);  

// set up
await ex(nftContract, "grantRole", [MINTER_ROLE, relayerAddress], "GR");
await ex(nftContract, "grantRole", [BURNER_ROLE, relayerAddress], "GR");

await verify(implementation, "MiPrimerNft", []);
}

async function upgrade() {


nftContract = await upgradeSC("MiPrimerNft_v2",nftProxy.address);
var implementation = await printAddress("MiPrimerNft_v2", nftContract.address);

await verify(implementation, "MiPrimerNft_v2", []);
}

async function deployGoerli() {
  // gnosis safe
  // Crear un gnosis safe en https://gnosis-safe.io/app/
  // Extraer el address del gnosis safe y pasarlo al contrato con un setter
  var gnosis = { address: "0x34C2BCC3a6CEeC2bd6F995A0f749Ceb55464C503" };
  miPrimerTokenContract = await deploySC("MiPrimerToken", []);
  var implementation = await printAddress("MiPrimerToken", miPrimerTokenContract.address);
  await verify(implementation, "MiPrimerToken", []);


  var usdcContract = await deploySCNoUp("USDCoin", []);
  console.log(`usdcContract Public Address: ${usdcContract.address}`); 
  await verify(usdcContract.address, "USDCoin", []);
  

  var miPrimerToken = miPrimerTokenContract.address;
  var usdc = usdcContract.address;
  

  publicSaleContract = await deploySC("PublicSale", []);
  var implementation = await printAddress("PublicSale", publicSaleContract.address);
  
  await ex(publicSaleContract, "setMiPrimerToken", [miPrimerToken], "GR");
  await ex(publicSaleContract, "setUSDCCoin", [usdc], "GR");
  await ex(publicSaleContract, "setGnosisWalletAdd", [gnosis.address], "GR");

  await verify(implementation, "PublicSale", []);

async function upgrade() {
  
  //var publicSaleProxy = publicSaleContract.address;
  publicSaleContract = await upgradeSC("PublicSale_v2",publicSaleProxy.address);
  var implementation = await printAddress("PublicSale_v2", publicSaleContract.address);

  await verify(implementation, "PublicSale_v2", []);
}
}  

deployMumbai()
//deployGoerli()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

