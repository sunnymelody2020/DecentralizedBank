// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DecentralizedBank} from "../src/DecentralizedBank.sol";

contract DecentralizedBankTest is Test {
    DecentralizedBank bank;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        bank = new DecentralizedBank();
    }

    function testSupply() public {
        vm.deal(alice, 10 ether);

        vm.prank(alice);
        bank.supply{value: 10 ether}();

        assertEq(bank.supplyShares(alice), 10 ether);
        assertEq(bank.totalSupplyShares(), 10 ether);
        assertEq(address(bank).balance, 10 ether);
    }

    function testWithdraw() public {
        vm.deal(alice, 10 ether);

        vm.prank(alice);
        bank.supply{value: 10 ether}();

        vm.prank(alice);
        bank.withdraw(4 ether);

        assertEq(bank.supplyShares(alice), 6 ether);
        assertEq(bank.totalSupplyShares(), 6 ether);
        assertEq(address(bank).balance, 6 ether);
    }

    function testTransfer() public {
        vm.deal(alice, 10 ether);

        vm.prank(alice);
        bank.supply{value: 10 ether}();

        vm.prank(alice);
        bank.transfer(bob, 4 ether);

        assertEq(bank.supplyShares(alice), 6 ether);
        assertEq(bank.supplyShares(bob), 4 ether);
        assertEq(bank.totalSupplyShares(), 10 ether);
    }

    function testBorrow() public {
        vm.deal(alice, 10 ether);

        vm.prank(alice);
        bank.supply{value: 10 ether}();

        vm.prank(alice);
        bank.borrow(5 ether);

        assertEq(bank.borrowed(alice), 5 ether);
        assertEq(address(bank).balance, 5 ether);
    }

    function testRepay() public {
        vm.deal(alice, 10 ether);

        vm.prank(alice);
        bank.supply{value: 10 ether}();

        vm.prank(alice);
        bank.borrow(5 ether);

        vm.deal(alice, 5 ether);

        vm.prank(alice);
        bank.repay{value: 3 ether}();

        assertEq(bank.borrowed(alice), 2 ether);
    }

    function testInterestAccrual() public {
        vm.deal(alice, 10 ether);

        vm.prank(alice);
        bank.supply{value: 10 ether}();

        vm.prank(alice);
        bank.borrow(5 ether);

        // Move time forward by 1 year
        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        bank.repay{value: 1 ether}();

        // 5 ETH debt should have accrued interest before the 1 ETH repayment
        assertGt(bank.borrowed(alice), 4 ether);
    }
}
