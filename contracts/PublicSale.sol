// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IUniSwapV2Router02 {
    //Receive an exact amount of output tokens for as few input tokens as possible
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    // comienzas por los primeros tokens
    // yo se cuanto voy a dar y no se cuanto me daran
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract PublicSale is
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    struct NFT {
        uint256 price;  //PRECIO VENDIDO
        address address_owner;
        bool isSold; //INDICA SI ESTA VENDIDO
    }
    uint256 totalOfNFT;

    mapping(uint256 => NFT) public nftsById;

    // Mi Primer Token// Crear su setter
    IERC20Upgradeable MiPrimerToken;
    address miPrimerToken;

    IERC20 USDCcoin;
    address usdc;
    
    function setMiPrimerToken(address _tokenAddress)  external {
        MiPrimerToken = IERC20Upgradeable(_tokenAddress);
        miPrimerToken = _tokenAddress;
    }
    function setUSDCCoin(address _usdc) external {
        USDCcoin = IERC20(_usdc);
        usdc = _usdc;
    }

    // 21 de diciembre del 2022 GMT
    uint256 constant startDate = 1671580800;

    // Maximo price NFT
    uint256 constant MAX_PRICE_NFT = 50000 * 10 ** 18;

    // Gnosis Safe
    // Crear su setter
    address gnosisSafeWallet;

    function setGnosisWalletAdd(address _gnosisSafeWallet) external {
        gnosisSafeWallet = _gnosisSafeWallet;
    }

    event DeliverNft(address winnerAccount, uint256 nftId);

    IUniSwapV2Router02 router;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(){
        _disableInitializers();
    }

    function initialize() public initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        totalOfNFT = 0;
         // Router Goerli
        router = IUniSwapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); 
    }

     function freeNftPurchased(uint256 tokenId) external {
        for(uint256 i=1; i<=30; i++){
            nftsById[tokenId] = NFT({
                    price : 0,  //PRECIO VENDIDO
                    address_owner : address(0),
                    isSold : false
            });
        }       
        totalOfNFT = 0;
     }

    function purchaseNftByIdAndUsdc(uint256 _id, uint256 _amountUSDC) external {

        require((_id > 0 && _id <= 30), "NFT: Token id out of range");
        require(!nftsById[_id].isSold, "Public Sale: id not available");
        
        uint256 allowance = USDCcoin.allowance(msg.sender, address(this));
        require(allowance >= _amountUSDC, "Public Sale: Not enough allowance");

        uint256 _balance = USDCcoin.balanceOf(msg.sender);
        require(_balance > 0,"Public Sale: Not enough token balance");
        
        uint256 _amountMPRTKN = _getPriceById(_id);

        USDCcoin.transferFrom(msg.sender, address(this), _amountUSDC);

        USDCcoin.approve(address(router), _amountUSDC);

        address[] memory path;
        path = new address[](2);
        path[0] = usdc;
        path[1] = miPrimerToken;

        uint deadline = block.timestamp;
        uint[] memory amounts = router.swapTokensForExactTokens(
            _amountMPRTKN,  //The amount of output tokens to receive.
            _amountUSDC,   //The maximum amount of input tokens that can be required before the transaction reverts.
            path,           //An array of token addresses. 
            address(this),  //Recipient of the output tokens.
            deadline        //Unix timestamp after which the transaction will revert.
        );

        //Refund usdc to msg.sender
        if (amounts[0] < _amountUSDC) {
            USDCcoin.transfer(msg.sender, _amountUSDC - amounts[0]);
        }

        uint256 _fee = (amounts[1] * 10) / 100;

        // enviar comision a Gnosis Safe desde los fondos de PublicSale
        MiPrimerToken.transferFrom(address(this), gnosisSafeWallet, _fee);

        nftsById[_id] = NFT({
                price : _amountMPRTKN,  //PRECIO VENDIDO
                address_owner : msg.sender,
                isSold : true
        });
        totalOfNFT++;

        // EMITIR EVENTO para que lo escuche OPEN ZEPPELIN DEFENDER
        emit DeliverNft(msg.sender, _id);
    }

    function purchaseNftById(uint256 _id) external {
        
        // 4 - el _id se encuentre entre 1 y 30
        //         * Mensaje de error: "NFT: Token id out of range"
        require((_id > 0 && _id <= 30), "NFT: Token id out of range");

        // 1 - el id no se haya vendido. Sugerencia: llevar la cuenta de ids vendidos
        //         * Mensaje de error: "Public Sale: id not available"
        require(!nftsById[_id].isSold, "Public Sale: id not available");
        
        // 2 - el msg.sender haya dado allowance a este contrato en suficiente de MPRTKN
        //         * Mensaje de error: "Public Sale: Not enough allowance"
        uint256 _allowance = MiPrimerToken.allowance(msg.sender, address(this));
        require(_allowance > 0,"Public Sale: Not enough allowance");
        
        // 3 - el msg.sender tenga el balance suficiente de MPRTKN
        //         * Mensaje de error: "Public Sale: Not enough token balance"
        uint256 _balance = MiPrimerToken.balanceOf(msg.sender);
        require(_balance > 0,"Public Sale: Not enough token balance");

        // Obtener el precio segun el id
        uint256 _amountMPRTKN = _getPriceById(_id);

        // Purchase fees
        // 10% para Gnosis Safe (fee)
        uint256 _fee = (_amountMPRTKN * 10) / 100;
        // 90% se quedan en este contrato (net)
        uint256 _net = _amountMPRTKN - _fee;
        // from: msg.sender - to: gnosisSafeWallet - amount: fee
        MiPrimerToken.transferFrom(msg.sender, gnosisSafeWallet, _fee);
        // from: msg.sender - to: address(this) - amount: net
        MiPrimerToken.transferFrom(msg.sender, address(this), _net);

        nftsById[_id] = NFT({
                price : _amountMPRTKN,  //PRECIO VENDIDO
                address_owner : msg.sender,
                isSold : true
        });
        totalOfNFT++;
        // EMITIR EVENTO para que lo escuche OPEN ZEPPELIN DEFENDER
        emit DeliverNft(msg.sender, _id);
    }

    function depositEthForARandomNft() public payable {
        // Realizar 2 validaciones
        // 1 - que el msg.value sea mayor o igual a 0.01 ether
        require(msg.value >= 0.01 ether, "Insuficiente cantidad de Ether");

        // 2 - que haya NFTs disponibles para hacer el random
        require(totalOfNFT <=30,"No hay NFTs disponibles");

        // Escgoer una id random de la lista de ids disponibles
        uint256 nftId = _getRandomNftId();

        // Enviar ether a Gnosis Safe
        // SUGERENCIA: Usar gnosisSafeWallet.call para enviar el ether
        // Validar los valores de retorno de 'call' para saber si se envio el ether correctamente
        (bool success, ) = payable(gnosisSafeWallet).call{
            value: 0.01 ether,
            gas: 500000
        }("");
        require(success, "Failed to send Ether");

        // Dar el cambio al usuario
        // El vuelto seria equivalente a: msg.value - 0.01 ether
        if (msg.value > 0.01 ether) {
            // logica para dar cambio
            // usar '.transfer' para enviar ether de vuelta al usuario
            uint256 _diffEther = msg.value - 0.01 ether;
            payable(msg.sender).transfer(_diffEther);
        }

        nftsById[nftId] = NFT({
                price : msg.value,  //PRECIO VENDIDO
                address_owner : msg.sender,
                isSold : true
        });
        totalOfNFT++;

        // EMITIR EVENTO para que lo escuche OPEN ZEPPELIN DEFENDER
        emit DeliverNft(msg.sender, nftId);
    }

    // PENDING
    // El contrato va a recibir ether
    receive() external payable {
        depositEthForARandomNft();
    }

    ////////////////////////////////////////////////////////////////////////
    /////////                    Helper Methods                    /////////
    ////////////////////////////////////////////////////////////////////////

    // Devuelve un id random de NFT de una lista de ids disponibles
    function _getRandomNftId() internal view returns (uint256) {
        uint256 id;
        
        //INTENTAMOS 5 VECES GENERAR UN ALEATORIO
        for (uint256 i = 1; i <= 5; i++) {
            id = (uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 30) + 1;
            if(!nftsById[id].isSold){                
                break;
            }
        }

        //BUSCAMOS EL PRIMER ID LIBRE
        if(nftsById[id].isSold){
            id = 0;
            for (uint256 i = 1; i <= 30; i++) {
                if(!nftsById[i].isSold){
                    id = i;
                    break;
                }
            }
            require(id > 0, "Public Sale: NFT not available");
        }
        return id;
    }

    function _checkExist(uint256 _id) internal view returns (bool){
        return nftsById[_id].isSold;
    }

    // Según el id del NFT, devuelve el precio. Existen 3 grupos de precios
    function _getPriceById(uint256 _id) internal view returns (uint256) {
        uint256 priceGroupOne = 500 ;
        uint256 priceGroupTwo = 1000 * _id;
        uint256 priceGroupThree = 10000;
        uint256 price;

        if (_id > 0 && _id < 11) {
            price = priceGroupOne;
        } else if (_id > 10 && _id < 21) {
            price = priceGroupTwo;
        } else {
            uint256 basePrice = 10000;
            uint256 hoursDiff = (block.timestamp - startDate) / 3600;
            priceGroupThree = basePrice + hoursDiff * 1000;
            if (priceGroupThree < 50000){
                price = priceGroupThree;
            }
            else{
                price = 50000;
            }            
        }
        return price * 10 ** 18;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    // Crear un método que permite recuperar lo tokens de MiPrimerToken almacenados en este contrato.
    function transferTokensFromThis()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        MiPrimerToken.transfer(msg.sender, MiPrimerToken.balanceOf(address(this)));   
    }

}