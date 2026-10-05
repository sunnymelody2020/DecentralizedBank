// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

error valuesMustBeGreaterThanZero();
error amountIsZero();
error addressIsZero();
error noSuppliedAsset();
error insufficientBankLiquidity();

contract DecentralizedBank {
    constructor() {
        lastAccrueledTime = block.timestamp;
    }

    uint256 public totalSupplyShares;
    uint256 public lastAccrueledTime;

    uint256 public borrowIndex = 1e18;

    uint256 public borrowRate = 8e16;
    uint256 constant YEAR = 365 days;

    mapping(address => uint256) public supplyShares;
    mapping(address => uint256) public borrowed;
    mapping(address => uint256) public lastBorrowedIndex;

    //EVENTS
    event supplied(address user, uint256 asset, uint256 shares);
    event withdrawn(address user, uint256 asset, uint256 shares);
    event transfered(address from, address to, uint256 amount);
    event borroweds(address user, uint256 amount);
    event repaid(address user, uint256 amount);

    //MODIFIERS
    modifier valueNotZero() {
        if (msg.value <= 0) {
            revert valuesMustBeGreaterThanZero();
        }
        _;
    }
    modifier amountGreaterThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert amountIsZero();
        }
        _;
    }

    modifier noZeroAddress(address _To) {
        if (_To == address(0)) {
            revert addressIsZero();
        }
        _;
    }
    modifier totalShareNotZero() {
        if (totalSupplyShares == 0) {
            revert noSuppliedAsset();
        }
        _;
    }
    modifier amountLessThanLiquidity(uint256 _amount) {
        if (_amount > address(this).balance) {
            revert insufficientBankLiquidity();
        }
        _;
    }

    function supply() public payable valueNotZero {
        accrueInterest();

        uint256 shares;

        if (totalSupplyShares == 0) {
            shares = msg.value;
        } else {
            uint256 totalAssetBefore = address(this).balance - msg.value;

            shares = (msg.value * totalSupplyShares) / totalAssetBefore;
        }
        totalSupplyShares += shares;
        supplyShares[msg.sender] += shares;

        emit supplied(msg.sender, msg.value, shares);
    }

    function sharesBalance() public view returns (uint256) {
        return supplyShares[msg.sender];
    }

    function withdraw(uint256 _amount) public amountGreaterThanZero(_amount) totalShareNotZero {
        accrueInterest();

        uint256 totalAsset = address(this).balance;

        uint256 shares = (_amount * totalSupplyShares + totalAsset - 1) / totalAsset;

        require(shares <= supplyShares[msg.sender], "Insufficient balance");

        supplyShares[msg.sender] -= shares;

        totalSupplyShares -= shares;

        (bool success,) = payable(msg.sender).call{value: _amount}("");

        require(success, "Transaction Failed");

        emit withdrawn(msg.sender, _amount, shares);
    }

    function accrueInterest() public {
        uint256 elapsed = block.timestamp - lastAccrueledTime;
        uint256 borrowInterest = (borrowRate * elapsed) / YEAR;

        borrowIndex = (borrowIndex * (1e18 + borrowInterest)) / 1e18;

        lastAccrueledTime = block.timestamp;
    }

    function balanceOf() public view returns (uint256) {
        if (totalSupplyShares == 0) {
            return 0;
        }
        uint256 totalAsset = address(this).balance;
        return (supplyShares[msg.sender] * totalAsset) / totalSupplyShares;
    }

    function transfer(address _To, uint256 _amount)
        public
        amountGreaterThanZero(_amount)
        noZeroAddress(_To)
        totalShareNotZero
    {
        uint256 totalAsset = address(this).balance;

        uint256 shares = (_amount * totalSupplyShares + totalAsset - 1) / totalAsset;

        require(shares <= supplyShares[msg.sender], "Insufficient balance");

        supplyShares[msg.sender] -= shares;
        supplyShares[_To] += shares;

        emit transfered(msg.sender, _To, _amount);
    }

    function borrow(uint256 _amount)
        public
        amountGreaterThanZero(_amount)
        totalShareNotZero
        amountLessThanLiquidity(_amount)
    {
        accrueInterest();
        updateBorrowInterest(msg.sender);

        uint256 totalAsset = address(this).balance;

        uint256 userBalance = (supplyShares[msg.sender] * totalAsset) / totalSupplyShares;

        uint256 maxBorrow = userBalance / 2;

        require(borrowed[msg.sender] + _amount <= maxBorrow, "Borrow limit exceeded");

        borrowed[msg.sender] += _amount;

        (bool success,) = payable(msg.sender).call{value: _amount}("");
        require(success, " transaction Failed");

        emit borroweds(msg.sender, _amount);
    }

    function borrowedBalance() public view returns (uint256) {
        return borrowed[msg.sender];
    }

    function repay() public payable valueNotZero {
        accrueInterest();
        updateBorrowInterest(msg.sender);

        require(msg.value <= borrowed[msg.sender], "Repay amount exceeds debt");

        borrowed[msg.sender] -= msg.value;

        emit repaid(msg.sender, msg.value);
    }

    function updateBorrowInterest(address _User) internal {
        uint256 userIndex = lastBorrowedIndex[_User];

        if (userIndex == 0) {
            lastBorrowedIndex[_User] = borrowIndex;
            return;
        }

        uint256 indexGrowth = borrowIndex - userIndex;

        uint256 interest = (borrowed[_User] * indexGrowth) / userIndex;

        borrowed[_User] += interest;
        lastBorrowedIndex[_User] = borrowIndex;
    }
}
