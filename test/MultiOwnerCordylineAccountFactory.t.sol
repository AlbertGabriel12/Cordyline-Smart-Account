// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

import {BaseCordylineAccountFactory} from "../src/common/BaseCordylineAccountFactory.sol";
import {MultiOwnerCordylineAccount} from "../src/MultiOwnerCordylineAccount.sol";
import {MultiOwnerCordylineAccountFactory} from "../src/MultiOwnerCordylineAccountFactory.sol";

contract MultiOwnerCordylineAccountFactoryTest is Test {
    uint256 internal constant _MAX_OWNERS_ON_CREATION = 100;

    address[] public owners;
    MultiOwnerCordylineAccountFactory public factory;
    EntryPoint public entryPoint;

    function setUp() public {
        entryPoint = new EntryPoint();
        factory = new MultiOwnerCordylineAccountFactory(address(this), entryPoint);
        owners = new address[](1);
        owners[0] = address(1);
    }

    function testReturnSameAddressWhenAccountAlreadyExists() public {
        MultiOwnerCordylineAccount account1 = factory.createAccountSingle(owners[0], 1);
        MultiOwnerCordylineAccount account2 = factory.createAccountSingle(owners[0], 1);
        MultiOwnerCordylineAccount account3 = factory.createAccount(owners, 1);
        assertEq(address(account1), address(account2));
        assertEq(address(account1), address(account3));
    }

    function testGetAddress() public {
        address counterfactual = factory.getAddress(owners, 1);
        assertEq(counterfactual.codehash, bytes32(0));
        MultiOwnerCordylineAccount factual = factory.createAccount(owners, 1);
        assertTrue(address(factual).codehash != bytes32(0));
        assertEq(counterfactual, address(factual));
    }

    function testGetAddressSingle() public {
        address counterfactual = factory.getAddress(owners, 1);
        assertEq(counterfactual.codehash, bytes32(0));
        MultiOwnerCordylineAccount factual = factory.createAccountSingle(owners[0], 1);
        assertTrue(address(factual).codehash != bytes32(0));
        assertEq(counterfactual, address(factual));
    }

    function testGetAddressAndCreateAccountWithMaxOwners() public {
        owners = new address[](_MAX_OWNERS_ON_CREATION);
        for (uint160 i = 0; i < _MAX_OWNERS_ON_CREATION; i++) {
            owners[i] = address(i + 1);
        }
        address counterfactual = factory.getAddress(owners, 1);
        MultiOwnerCordylineAccount factual = factory.createAccount(owners, 1);
        assertEq(counterfactual, address(factual));
    }

    function testGetAddressAndCreateAccountWithTooManyOwners() public {
        owners = new address[](_MAX_OWNERS_ON_CREATION + 1);
        for (uint160 i = 0; i < _MAX_OWNERS_ON_CREATION + 1; i++) {
            owners[i] = address(i + 1);
        }
        vm.expectRevert(MultiOwnerCordylineAccountFactory.OwnersLimitExceeded.selector);
        factory.getAddress(owners, 1);
        vm.expectRevert(MultiOwnerCordylineAccountFactory.OwnersLimitExceeded.selector);
        factory.createAccount(owners, 1);
    }

    function testGetAddressAndCreateAccountWithDescendingOwners() public {
        owners = new address[](3);
        owners[0] = address(100);
        owners[1] = address(99);
        owners[1] = address(98);
        vm.expectRevert(MultiOwnerCordylineAccountFactory.InvalidOwners.selector);
        factory.getAddress(owners, 1);
        vm.expectRevert(MultiOwnerCordylineAccountFactory.InvalidOwners.selector);
        factory.createAccount(owners, 1);
    }

    function testGetAddressAndCreateAccountWithDuplicateOwners() public {
        owners = new address[](3);
        owners[0] = address(100);
        owners[1] = address(101);
        owners[1] = address(101);
        vm.expectRevert(MultiOwnerCordylineAccountFactory.InvalidOwners.selector);
        factory.getAddress(owners, 1);
        vm.expectRevert(MultiOwnerCordylineAccountFactory.InvalidOwners.selector);
        factory.createAccount(owners, 1);
    }

    function testGetAddressAndCreateAccountWithZeroAddress() public {
        owners = new address[](3);
        owners[0] = address(0);
        owners[1] = address(100);
        owners[1] = address(101);
        vm.expectRevert(MultiOwnerCordylineAccountFactory.InvalidOwners.selector);
        factory.getAddress(owners, 1);
        vm.expectRevert(MultiOwnerCordylineAccountFactory.InvalidOwners.selector);
        factory.createAccount(owners, 1);
        vm.expectRevert(MultiOwnerCordylineAccountFactory.InvalidOwners.selector);
        factory.createAccountSingle(address(0), 1);
    }

    function testGetAddressAndCreateAccountWithEmptyOwners() public {
        owners = new address[](0);
        vm.expectRevert(MultiOwnerCordylineAccountFactory.OwnersArrayEmpty.selector);
        factory.getAddress(owners, 1);
        vm.expectRevert(MultiOwnerCordylineAccountFactory.OwnersArrayEmpty.selector);
        factory.createAccount(owners, 1);
    }

    function testAddStake() public {
        assertEq(entryPoint.balanceOf(address(factory)), 0);
        vm.deal(address(this), 100 ether);
        factory.addStake{value: 10 ether}(10 hours, 10 ether);
        assertEq(entryPoint.getDepositInfo(address(factory)).stake, 10 ether);
    }

    function testUnlockStake() public {
        testAddStake();
        factory.unlockStake();
        assertEq(entryPoint.getDepositInfo(address(factory)).withdrawTime, block.timestamp + 10 hours);
    }

    function testWithdrawStake() public {
        testUnlockStake();
        vm.warp(10 hours);
        vm.expectRevert("Stake withdrawal is not due");
        factory.withdrawStake(payable(address(this)));
        assertEq(address(this).balance, 90 ether);
        vm.warp(10 hours + 1);
        factory.withdrawStake(payable(address(this)));
        assertEq(address(this).balance, 100 ether);
    }

    function testWithdrawStakeToZeroAddress() public {
        testUnlockStake();
        vm.expectRevert(BaseCordylineAccountFactory.ZeroAddressNotAllowed.selector);
        factory.withdrawStake(payable(address(0)));
    }

    function testWithdraw() public {
        factory.addStake{value: 10 ether}(10 hours, 1 ether);
        assertEq(address(factory).balance, 9 ether);
        factory.withdraw(payable(address(this)), address(0), 0); // amount = balance if native currency
        assertEq(address(factory).balance, 0);
    }

    function testWithdrawToZeroAddress() public {
        factory.addStake{value: 10 ether}(10 hours, 1 ether);
        vm.expectRevert(BaseCordylineAccountFactory.ZeroAddressNotAllowed.selector);
        factory.withdraw(payable(address(0)), address(0), 0);
    }

    function test2StepOwnershipTransfer() public {
        address owner1 = address(0x200);
        assertEq(factory.owner(), address(this));
        factory.transferOwnership(owner1);
        assertEq(factory.owner(), address(this));
        vm.prank(owner1);
        factory.acceptOwnership();
        assertEq(factory.owner(), owner1);
    }

    function testCannotRenounceOwnership() public {
        vm.expectRevert(BaseCordylineAccountFactory.InvalidAction.selector);
        factory.renounceOwnership();
    }

    function testRevertWithInvalidEntryPoint() public {
        IEntryPoint invalidEntryPoint = IEntryPoint(address(123));
        vm.expectRevert(
            abi.encodeWithSelector(BaseCordylineAccountFactory.InvalidEntryPoint.selector, (address(invalidEntryPoint)))
        );
        new MultiOwnerCordylineAccountFactory(address(this), invalidEntryPoint);
    }

    /// @dev Receive funds from withdraw.
    receive() external payable {}
}
