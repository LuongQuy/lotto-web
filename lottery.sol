pragma solidity ^0.4.19;

contract Ownable {
    address public owner;

    function Ownable() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }

}


contract Lottery is Ownable {
    address public drawer;

    struct Game {
        uint startTime;
        uint jackpot;
        uint reserve;
        uint price;
        bytes winNumbers;
        mapping(byte => bool) winNumbersMap;
        Ticket[] tickets;
        uint checkWinTicketLevel;
        uint[][] winTicketIndices;
        uint[] winLevelAmounts;
        uint needPlayersTransfer;
        uint addToJackpotAmount;
        uint addToReserveAmount;
        uint bitcoinBlockIndex;
        string bitcoinBlockHash;
    }

    struct Ticket {
        address user;
        bytes numbers;
    }

    mapping(address => uint[2][]) playerTickets;

    mapping(address => bool) isBonusAddress;

    Game[] public games;

    uint public gameIndex;

    uint public gameIndexToBuy;

    uint public checkGameIndex;

    uint public numbersCount;

    uint public numbersCountMax;

    uint public ticketCountMax;

    uint public jackpotGuaranteed;

    uint public disableBuyingTime;

    uint[] public winPercent;

    address public dividendsWallet;

    address public technicalWallet;

    address public prWallet;

    uint public dividendsPercent;

    uint public technicalPercent;

    uint public prPercent;

    bool public buyEnable = true;

    uint public nextPrice;

    uint public intervalTime;

    modifier onlyDrawer() {
        require(msg.sender == drawer);
        _;
    }
    function setDrawer(address _drawer) public onlyOwner {
        drawer = _drawer;
    }


    event LogTransfer(uint indexed gameIndex, uint riseAmount, uint technicalAmount, uint dividendsAmount, uint prAmount);

    event LogDraw(uint indexed gameIndex, uint startTime, uint bitcoinBlockIndex, bytes numbers, uint riseAmount, uint transferAmount, uint addToJackpotAmount, uint addToReserveAmount);

    event LogReserveUsed(uint indexed gameIndex, uint amount);

    function Lottery() public {

        drawer = msg.sender;
        dividendsWallet = msg.sender;
        technicalWallet = msg.sender;
        prWallet = msg.sender;

        dividendsPercent = 10;
        technicalPercent = 5;
        prPercent = 15;

        disableBuyingTime = 1 hours;
        intervalTime = 6 hours;

        nextPrice = 0.003 ether;

        games.length += 2;

        numbersCount = 6;
        numbersCountMax = 45;
        winPercent = [0, 0, 20, 20, 20, 20, 20];

        jackpotGuaranteed = 1000 ether;
        ticketCountMax = 1000000;
        games[0].startTime = 1514872800;

        games[0].price = nextPrice;
        games[1].price = nextPrice;

        games[1].startTime = games[0].startTime + intervalTime;


    }

    function startTime() public view returns (uint){
        return games[gameIndex].startTime;
    }

    function closeTime() public view returns (uint){
        return games[gameIndex].startTime - disableBuyingTime;
    }

    function addReserve() public payable {
        require(checkGameIndex == gameIndex);
        games[gameIndex].reserve += msg.value;
    }

    function addBalance() public payable {

    }

    function isNeedCloseCurrentGame() public view returns (bool){
        return games[gameIndex].startTime < disableBuyingTime + now && gameIndexToBuy == gameIndex;
    }

    function closeCurrentGame(uint bitcoinBlockIndex) public onlyDrawer {
        if (isNeedCloseCurrentGame()) {
            games[gameIndex].bitcoinBlockIndex = bitcoinBlockIndex;
            gameIndexToBuy = gameIndex + 1;
        }
    }

    function() public payable {
        uint[] memory numbers = new uint [](msg.data.length);

        for (uint i = 0; i < msg.data.length; i++) {
            numbers[i] = uint((msg.data[i] >> 4) & 0xF) * 10 + uint(msg.data[i] & 0xF);
        }
        buyTicket(numbers, address(0));
    }

    function buyTicket(uint[] numbers, address bonusAddress) public payable {
        require(buyEnable);
        require(numbers.length % numbersCount == 0);

        Game storage game = games[gameIndexToBuy];

        uint buyTicketCount = numbers.length / numbersCount;
        require(msg.value == game.price * buyTicketCount);
        require(game.tickets.length + buyTicketCount <= ticketCountMax);

        uint i = 0;
        while (i < numbers.length) {

            bytes memory bet = new bytes(numbersCount);

            for (uint j = 0; j < numbersCount; j++) {
                bet[j] = byte(numbers[i++]);
            }

            require(noDuplicates(bet));

            playerTickets[msg.sender].push([gameIndexToBuy, game.tickets.length]);

            game.tickets.push(Ticket(msg.sender, bet));

        }

        if (isBonusAddress[bonusAddress]) {
            bonusAddress.transfer(msg.value * prPercent / 100);
        } else {
            prWallet.transfer(msg.value * prPercent / 100);
        }
    }

    function getPlayerTickets(address player, uint offset, uint count) public view returns (int [] tickets){
        uint[2][] storage list = playerTickets[player];
        if (offset >= list.length) return tickets;

        uint k;
        uint n = offset + count;
        if (n > list.length) n = list.length;

        tickets = new int []((n - offset) * (numbersCount + 5));

        for (uint i = offset; i < n; i++) {
            var info = list[list.length - i - 1];
            uint gameIndex = info[0];

            tickets[k++] = int(gameIndex);
            tickets[k++] = int(info[1]);
            tickets[k++] = int(games[gameIndex].startTime);

            if (games[gameIndex].winNumbers.length == 0) {
                tickets[k++] = - 1;
                tickets[k++] = int(games[gameIndex].price);

                for (uint j = 0; j < numbersCount; j++) {
                    tickets[k++] = int(games[gameIndex].tickets[info[1]].numbers[j]);
                }
            }
            else {
                uint winNumbersCount = getEqualCount(games[gameIndex].tickets[info[1]].numbers, games[gameIndex]);
                tickets[k++] = int(games[gameIndex].winLevelAmounts[winNumbersCount]);
                tickets[k++] = int(games[gameIndex].price);

                for (j = 0; j < numbersCount; j++) {
                    if (games[gameIndex].winNumbersMap[games[gameIndex].tickets[info[1]].numbers[j]]) {
                        tickets[k++] = - int(games[gameIndex].tickets[info[1]].numbers[j]);
                    }
                    else {
                        tickets[k++] = int(games[gameIndex].tickets[info[1]].numbers[j]);
                    }
                }
            }
        }
    }

    function getGames(uint offset, uint count) public view returns (uint [] res){
        if (offset > gameIndex) return res;

        uint k;
        uint n = offset + count;
        if (n > gameIndex + 1) n = gameIndex + 1;
        res = new uint []((n - offset) * (numbersCount + 10));

        for (uint i = offset; i < n; i++) {
            uint gi = gameIndex - i;
            Game storage game = games[gi];
            res[k++] = gi;
            res[k++] = game.startTime;
            res[k++] = game.jackpot;
            res[k++] = game.reserve;
            res[k++] = game.price;
            res[k++] = game.tickets.length;
            res[k++] = game.needPlayersTransfer;
            res[k++] = game.addToJackpotAmount;
            res[k++] = game.addToReserveAmount;
            res[k++] = game.bitcoinBlockIndex;

            if (game.winNumbers.length == 0) {
                for (uint j = 0; j < numbersCount; j++) {
                    res[k++] = 0;
                }
            }
            else {
                for (j = 0; j < numbersCount; j++) {
                    res[k++] = uint(game.winNumbers[j]);
                }
            }
        }
    }

    function getWins(uint gameIndex, uint offset, uint count) public view returns (uint[] wins){
        Game storage game = games[gameIndex];
        uint k;
        uint n = offset + count;
        uint[] memory res = new uint [](count * 4);

        uint currentIndex;

        for (uint level = numbersCount; level > 1; level--) {
            for (uint indexInlevel = 0; indexInlevel < game.winTicketIndices[level].length; indexInlevel++) {
                if (offset <= currentIndex && currentIndex < n) {
                    uint ticketIndex = game.winTicketIndices[level][indexInlevel];
                    Ticket storage ticket = game.tickets[ticketIndex];
                    res[k++] = uint(ticket.user);
                    res[k++] = level;
                    res[k++] = ticketIndex;
                    res[k++] = game.winLevelAmounts[level];

                } else if (currentIndex >= n) {
                    wins = new uint[](k);
                    for (uint i = 0; i < k; i++) {
                        wins[i] = res[i];
                    }
                    return wins;
                }
                currentIndex++;
            }
        }
        wins = new uint[](k);
        for (i = 0; i < k; i++) {
            wins[i] = res[i];
        }
    }

    function noDuplicates(bytes array) public pure returns (bool){
        for (uint i = 0; i < array.length - 1; i++) {
            for (uint j = i + 1; j < array.length; j++) {
                if (array[i] == array[j]) return false;
            }
        }
        return true;
    }

    function getWinNumbers(string bitcoinBlockHash, uint numbersCount, uint numbersCountMax) public pure returns (bytes){
        bytes32 random = keccak256(bitcoinBlockHash);
        bytes memory allNumbers = new bytes(numbersCountMax);
        bytes memory winNumbers = new bytes(numbersCount);

        for (uint i = 0; i < numbersCountMax; i++) {
            allNumbers[i] = byte(i + 1);
        }

        for (i = 0; i < numbersCount; i++) {
            uint n = numbersCountMax - i;

            uint r = uint(random[random.length - 1 - i]) % n;

            winNumbers[i] = allNumbers[r];

            allNumbers[r] = allNumbers[n - 1];

        }
        return winNumbers;
    }

    function isNeedDrawGame(uint bitcoinBlockIndex) public view returns (bool){
        Game storage game = games[gameIndex];
        return bitcoinBlockIndex > game.bitcoinBlockIndex && game.bitcoinBlockIndex > 0 && now >= game.startTime;
    }

    function drawGame(uint bitcoinBlockIndex, string bitcoinBlockHash) public onlyDrawer {
        Game storage game = games[gameIndex];

        require(isNeedDrawGame(bitcoinBlockIndex));

        game.bitcoinBlockIndex = bitcoinBlockIndex;
        game.bitcoinBlockHash = bitcoinBlockHash;
        game.winNumbers = getWinNumbers(bitcoinBlockHash, numbersCount, numbersCountMax);

        for (uint i = 0; i < game.winNumbers.length; i++) {
            game.winNumbersMap[game.winNumbers[i]] = true;
        }

        game.winTicketIndices.length = numbersCount + 1;
        game.winLevelAmounts.length = numbersCount + 1;

        uint riseAmount = game.tickets.length * game.price;

        uint technicalAmount = riseAmount * technicalPercent / 100;
        uint dividendsAmount = riseAmount * dividendsPercent / 100;
        uint prAmount = riseAmount * prPercent / 100;

        technicalWallet.transfer(technicalAmount);
        dividendsWallet.transfer(dividendsAmount);

        LogTransfer(gameIndex, riseAmount, technicalAmount, dividendsAmount, prAmount);

        games.length++;

        gameIndex++;
        games[gameIndex + 1].startTime = games[gameIndex].startTime + intervalTime;
        games[gameIndex + 1].price = nextPrice;

    }

    function calcWins(Game storage game) private {
        game.checkWinTicketLevel = numbersCount;

        uint riseAmount = game.tickets.length * game.price * (100 - technicalPercent - dividendsPercent - prPercent) / 100;

        uint freeAmount = 0;

        for (uint i = 2; i < numbersCount; i++) {
            uint winCount = game.winTicketIndices[i].length;
            uint winAmount = riseAmount * winPercent[i] / 100;
            if (winCount > 0) {
                game.winLevelAmounts[i] = winAmount / winCount;
                game.needPlayersTransfer += winAmount;
            }
            else {
                freeAmount += winAmount;
            }
        }
        freeAmount += riseAmount * winPercent[numbersCount] / 100;

        uint winJackpotCount = game.winTicketIndices[numbersCount].length;

        uint jackpot = game.jackpot;
        uint reserve = game.reserve;

        if (winJackpotCount > 0) {
            if (jackpot < jackpotGuaranteed) {
                uint fromReserve = jackpotGuaranteed - jackpot;
                if (fromReserve > reserve) fromReserve = reserve;

                reserve -= fromReserve;
                jackpot += fromReserve;

                LogReserveUsed(checkGameIndex, fromReserve);
            }

            game.winLevelAmounts[numbersCount] = jackpot / winJackpotCount;

            game.needPlayersTransfer += jackpot;
            jackpot = 0;
        }

        if (reserve < jackpotGuaranteed) {
            game.addToReserveAmount = freeAmount;
        } else {
            game.addToJackpotAmount = freeAmount;
        }

        games[checkGameIndex + 1].jackpot += jackpot + game.addToJackpotAmount;
        games[checkGameIndex + 1].reserve += reserve + game.addToReserveAmount;

    }

    function getEqualCount(bytes numbers, Game storage game) constant private returns (uint count){
        for (uint i = 0; i < numbers.length; i++) {
            if (game.winNumbersMap[numbers[i]]) count++;
        }
    }

    function setJackpotGuaranteed(uint _jackpotGuaranteed) public onlyOwner {
        jackpotGuaranteed = _jackpotGuaranteed;
    }

}

