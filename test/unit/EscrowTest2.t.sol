// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {EscrowTestBase} from "../EscrowTestBase.t.sol";
import {Test} from "forge-std/Test.sol";
import {IEscrow, Escrow} from "../../src/Escrow.sol";
import {MyEscrow} from "../../src/MyEscrow.sol";
import {EscrowFactory} from "../../src/EscrowFactory.sol";
import {MyEscrowFactory} from "../../src/MyEscrowFactory.sol";
import {DeployEscrowFactory} from "../../script/DeployEscrowFactory.s.sol";
import {DeployMyEscrowFactory} from "../../script/DeployMyEscrowFactory.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {ERC20MockFailedTransfer} from "../mocks/ERC20MockFailedTransfer.sol";
import {console} from "forge-std/console.sol";

contract EsrowTest2 is EscrowTestBase, Test {
    EscrowFactory public escrowFactory;
    MyEscrowFactory public myEscrowFactory;
    address public constant SOME_DEPLOYER = address(4);
    IEscrow public escrow;
    uint256 public buyerAward = 0;
    uint256 public EXTRA_TOKENS = 1e18;
    IEscrow public myEscrow;
    uint256 public constant BUYER_DISPUTE_REWARD = 1e17;

    // events
    event Confirmed(address indexed seller);
    event Disputed(address indexed disputer);
    event Resolved(address indexed buyer, address indexed seller);

    function setUp() external {
        DeployEscrowFactory deployer = new DeployEscrowFactory();
        escrowFactory = deployer.run();

        DeployMyEscrowFactory myDeployer = new DeployMyEscrowFactory();
        myEscrowFactory = myDeployer.run();
    }

    modifier escrowDeployedWithExtraTokens() {
        vm.startPrank(BUYER);
        ERC20Mock(address(i_tokenContract)).mint(BUYER, PRICE + EXTRA_TOKENS);
        ERC20Mock(address(i_tokenContract)).approve(address(escrowFactory), PRICE + EXTRA_TOKENS);
        escrow = escrowFactory.newEscrow(PRICE, i_tokenContract, SELLER, ARBITER, ARBITER_FEE, SALT1);
        vm.stopPrank();
        _;
    }

    modifier myEscrowDeployed() {
        vm.startPrank(BUYER);
        ERC20Mock(address(i_tokenContract)).mint(BUYER, PRICE + EXTRA_TOKENS);
        ERC20Mock(address(i_tokenContract)).approve(address(myEscrowFactory), PRICE + EXTRA_TOKENS);
        myEscrow = myEscrowFactory.newEscrow(PRICE, i_tokenContract, SELLER, ARBITER, ARBITER_FEE, SALT1);
        vm.stopPrank();
        _;
    }

    function testBuyerShouldBeAbleToGetExtraTokensThanPrice() public escrowDeployedWithExtraTokens {
        vm.startPrank(BUYER);

        // assuming buyer sent extra tokens to escrow by mistake (e.g. wrong token address)
        i_tokenContract.transfer(address(escrow), EXTRA_TOKENS);
        escrow.confirmReceipt();
        uint256 sellerBalance = i_tokenContract.balanceOf(SELLER);
        assertEq(sellerBalance, PRICE + EXTRA_TOKENS);

        // buyer should have lost extra tokens
        uint256 buyerBalance = i_tokenContract.balanceOf(BUYER);
        assertEq(buyerBalance, 0);
        vm.stopPrank();
    }

    function testUpdatedContractShouldSendExtraTokenBackToBuyer() public myEscrowDeployed {
        vm.startPrank(BUYER);

        // assuming buyer sent extra tokens to escrow by mistake (e.g. wrong token address)
        i_tokenContract.transfer(address(myEscrow), EXTRA_TOKENS);
        myEscrow.confirmReceipt();
        uint256 sellerBalance = i_tokenContract.balanceOf(SELLER);
        assertEq(sellerBalance, PRICE);

        // extra tokens transferred should be sent back to the buyer
        uint256 buyerBalance = i_tokenContract.balanceOf(BUYER);
        assertEq(buyerBalance, EXTRA_TOKENS);
        vm.stopPrank();
    }

    function testFail_ExtraTokenTransferredToEscrowShouldBeReturnedBack() public escrowDeployedWithExtraTokens {
        vm.startPrank(BUYER);
        i_tokenContract.transfer(address(escrow), EXTRA_TOKENS);

        // raising dispute
        escrow.initiateDispute();

        // should not be able to call the confirmReceipt funciton
        vm.expectRevert();
        escrow.confirmReceipt();
        vm.stopPrank();

        // resolving disupte
        vm.startPrank(ARBITER);
        escrow.resolveDispute(BUYER_DISPUTE_REWARD);

        // checking balance of the
        uint256 buyerBalance = i_tokenContract.balanceOf(BUYER);
        uint256 sellerBalance = i_tokenContract.balanceOf(SELLER);
        uint256 arbiterBalance = i_tokenContract.balanceOf(ARBITER);



        console.log(buyerBalance);
        console.log(sellerBalance);
        console.log(arbiterBalance);

        assertEq(buyerBalance, BUYER_DISPUTE_REWARD + EXTRA_TOKENS);
        assertEq(sellerBalance, PRICE - BUYER_DISPUTE_REWARD - ARBITER_FEE);
        assertEq(arbiterBalance, ARBITER_FEE);
    }


    function testExtraTokensShouldNotBeTransferredToBuyerInCaseOfDispute() public myEscrowDeployed {
        vm.startPrank(BUYER);
        i_tokenContract.transfer(address(myEscrow), EXTRA_TOKENS);

        // raising dispute
        myEscrow.initiateDispute();

        // should not be able to call the confirmReceipt funciton
        vm.expectRevert();
        myEscrow.confirmReceipt();
        vm.stopPrank();

        // resolving disupte
        vm.startPrank(ARBITER);
        myEscrow.resolveDispute(BUYER_DISPUTE_REWARD);

        // checking balance of the
        uint256 buyerBalance = i_tokenContract.balanceOf(BUYER);
        uint256 sellerBalance = i_tokenContract.balanceOf(SELLER);
        uint256 arbiterBalance = i_tokenContract.balanceOf(ARBITER);

        assertEq(buyerBalance, BUYER_DISPUTE_REWARD + EXTRA_TOKENS);
        assertEq(sellerBalance, PRICE - BUYER_DISPUTE_REWARD - ARBITER_FEE);
        assertEq(arbiterBalance, ARBITER_FEE);
    }
}
