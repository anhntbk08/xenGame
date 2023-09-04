pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/xenBurn.sol";
import "../src/xenPriceOracle.sol";
import "../src/PlayerNameRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract XenBurnTest is Test {
    xenBurn public XenBurnInstance;
    PriceOracle public priceOracleInstance;
    address public xenCrypto = 0x06450dEe7FD2Fb8E39061434BAbCFC05599a6Fb8;
    uint256 public initialBalance = 1 ether;
    PlayerNameRegistry public playerNameRegistry;
    IERC20 private _xenCryptoInstance;

    function setUp() public {
        priceOracleInstance = new PriceOracle();
        playerNameRegistry = new PlayerNameRegistry(payable(address(4)), payable(address(5)));
        XenBurnInstance = new xenBurn(address(priceOracleInstance), xenCrypto, address(playerNameRegistry));
        _xenCryptoInstance = IERC20(xenCrypto);
    }

    function testDeposit() public {
        vm.deal(msg.sender, initialBalance);
        XenBurnInstance.deposit{value: initialBalance}();
        assertEq(address(XenBurnInstance).balance, initialBalance, "Deposit unsuccessful.");
    }

    function testCalculateExpectedBurnAmount() public {
        testDeposit();

        uint256 expectedBurnAmount = XenBurnInstance.calculateExpectedBurnAmount();

        console.log("expectedBurnAmount", expectedBurnAmount);
        assertTrue(expectedBurnAmount > 0, "Expected burn amount should be greater than 0");
    }

    function approveXenCryptoSpending(uint256 amount) public {
        _xenCryptoInstance.approve(address(XenBurnInstance), amount);
    }

    function testBurnXenCrypto() public {
        testDeposit();

        uint256 NAME_REGISTRATION_FEE = 20000000000000000; // 0.02 Ether in Wei
        string memory userName = "Alice";

        uint256 expectedBurnAmount = XenBurnInstance.calculateExpectedBurnAmount();
        vm.startPrank(address(1));
        approveXenCryptoSpending(expectedBurnAmount);

        try playerNameRegistry.registerPlayerName{value: NAME_REGISTRATION_FEE}(address(1), userName) {
            string memory name = playerNameRegistry.getPlayerFirstName(address(1));
            console.log("Registered name:", name);

            } catch Error(string memory reason) {
                fail(reason);
            } catch (bytes memory) /*lowLevelData*/ {
                fail("Low level error on registering name");
        }
        

        try XenBurnInstance.burnXenCrypto() {
            console.log("Burn operation successful.");
        } catch Error(string memory reason) {
            console.log("Error encountered:", reason);
        } catch (bytes memory ) /*lowLevelData*/ {
            console.log("Low level error");
        }

        vm.stopPrank();
    }

    // function testWasBurnSuccessful() public {
    //     bool burnSuccessful = XenBurnInstance.wasBurnSuccessful(msg.sender);
    //     assertTrue(burnSuccessful, "Token burn should be successful");
    // }
}
