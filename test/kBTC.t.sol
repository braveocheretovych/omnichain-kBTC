// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {OFT} from "../src/OFT.sol";
import {kBTC} from "../src/kBTC.sol";
import {offChainSignatureAggregator} from "../src/offChainSignatureAggregator.sol";
import {ProxyTestHelper} from "./utils/ProxyTestHelper.sol";
contract UnitTest is ProxyTestHelper {
    uint32 aEid = 1;
    address internal signer;
    uint256 internal signerPrivateKey;
    kBTC internal kbtc;
    offChainSignatureAggregator internal agg;
    function setUp() public virtual override{
        super.setUp();
        setUpEndpoints(1, LibraryType.UltraLightNode);

        signerPrivateKey = 0xA11CE;
        signer = vm.addr(signerPrivateKey);
        vm.startPrank(signer);
        kbtc = kBTC(
            _deployOAppProxyGeneralized(
                type(kBTC).creationCode,
                abi.encodeWithSelector(OFT.initialize.selector, "kbtc", "kbtc", address(endpoints[aEid]), signer)
            )
        );
        agg = new offChainSignatureAggregator(address(kbtc));
        kbtc.updateAggregator(address(agg));
        address[] memory signers = new address[](1);
        bool[] memory valids = new bool[](1);
        signers[0] = signer;
        valids[0] = true;
        agg.setSigners(signers, valids);
    }

    function mint(address receiver, uint256 amount) public {
        uint256 nonce = agg.nonce();
        uint256 beforeBalance = kbtc.balanceOf(receiver);
        offChainSignatureAggregator.Report memory report = offChainSignatureAggregator.Report({
            receiver: receiver,
            amount: amount,
            nonce: nonce + 1
        }
            
        );
        vm.startPrank(signer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerPrivateKey,
            keccak256(abi.encodePacked("\x19\x01", agg.DOMAIN_SEPARATOR(), agg.reportDigest(report)))
        );
        offChainSignatureAggregator.Signature[] memory _rs = new offChainSignatureAggregator.Signature[](1);
        offChainSignatureAggregator.Signature memory rep = offChainSignatureAggregator.Signature({
            v: v,
            r: r,
            s: s
        }       
        );
        _rs[0] = rep;
        agg.mintBTC(report, _rs);
        require(beforeBalance + amount == kbtc.balanceOf(receiver));
    }

    function burn(address burner, uint256 amount) public {
        require(kbtc.balanceOf(burner) >= amount);
        uint256 beforeBalance = kbtc.balanceOf(burner);
        vm.startPrank(burner);
        string memory btcAddress = "tb1pap6uaw5y693cx69d0we2ex6ymclyr2k3esm30p32g20sa94aykrsgjcdec";
        kbtc.burn(amount, btcAddress);
        require(beforeBalance - amount == kbtc.balanceOf(burner));
    }

    function testMint() public {
        address receiver = address(0x1);
        uint256 amount = 1e18;
        mint(receiver, amount);
    }

    function testBurn() public {
        address receiver = address(0x1);
        uint256 amount = 1e18;
        mint(receiver, amount);
        burn(receiver, amount);

    }

    function testEmergencyBurn() public {
        address receiver = address(0x1);
        uint256 amount = 1e18;
        mint(receiver, amount);
        vm.startPrank(signer);
        kbtc.emergencyBurn(receiver, amount);
    }

    function _deployOAppProxy(address _endpoint, address _owner, address implementationAddress)
        internal
        override
        returns (address proxyAddress)
    {}
}