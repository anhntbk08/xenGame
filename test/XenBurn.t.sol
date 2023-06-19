pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/xenBurn.sol";
import "../src/xenPriceOracle.sol";

contract XenBurnTest is Test {
    xenBurn public XenBurnInstance;
    PriceOracle public priceOracleInstance;
    address public xenCrypto = 0x06450dEe7FD2Fb8E39061434BAbCFC05599a6Fb8; 
    uint public initialBalance = 1 ether;

    function setUp() public {
        priceOracleInstance = new PriceOracle();
        XenBurnInstance = new xenBurn(address(priceOracleInstance), xenCrypto);
    }

    function testDeposit() public {
        vm.deal(msg.sender, initialBalance);
        XenBurnInstance.deposit{value: initialBalance}();
        assertEq(address(XenBurnInstance).balance, initialBalance, "Deposit unsuccessful.");
    }

    function testCalculateExpectedBurnAmount() public {

        testDeposit();
        
        uint256 expectedBurnAmount = XenBurnInstance.calculateExpectedBurnAmount();
        assertTrue(expectedBurnAmount > 0, "Expected burn amount should be greater than 0");
    }

    function testBurnXenCrypto() public {
        testDeposit();
        
        vm.startPrank(address(XenBurnInstance));

        try XenBurnInstance.burnXenCrypto() {
            console.log("Burn operation successful.");
        } 
        catch Error(string memory reason) {
            console.log("Error encountered:", reason);
        } 
        catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error");
        }

        vm.stopPrank();
    }

    function testWasBurnSuccessful() public {
        bool burnSuccessful = XenBurnInstance.wasBurnSuccessful(msg.sender);
        assertTrue(burnSuccessful, "Token burn should be successful");
    }

}