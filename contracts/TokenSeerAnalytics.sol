State Variables
    address public owner;
    uint256 public totalTransactionsTracked;
    uint256 public totalTokensAnalyzed;
    
    Mappings
    mapping(address => TokenMetrics) public tokenMetrics;
    mapping(address => bool) public isTokenRegistered;
    mapping(uint256 => TransactionData) public transactions;
    mapping(address => uint256[]) public tokenTransactionIds;
    mapping(address => mapping(address => bool)) public hasInteracted;
    mapping(uint256 => AnalyticsSnapshot) public snapshots;
    
    Events
    event TokenRegistered(address indexed tokenAddress, string tokenName, string tokenSymbol, uint256 timestamp);
    event TransactionRecorded(uint256 indexed transactionId, address indexed tokenAddress, address from, address to, uint256 amount);
    event MetricsUpdated(address indexed tokenAddress, uint256 transactionCount, uint256 uniqueHolders, uint256 timestamp);
    event SnapshotCreated(uint256 indexed snapshotId, address indexed tokenAddress, uint256 volume24h, uint256 timestamp);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    Constructor
    constructor() {
        owner = msg.sender;
        totalTransactionsTracked = 0;
        totalTokensAnalyzed = 0;
        snapshotCounter = 0;
    }
    
    /**
     * @dev Register a new token for analytics tracking
     * @param _tokenAddress Address of the token contract
     * @param _tokenName Name of the token
     * @param _tokenSymbol Symbol of the token
     * @param _totalSupply Total supply of the token
     */
    function registerToken(
        address _tokenAddress,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _totalSupply
    ) external onlyOwner validAddress(_tokenAddress) {
        require(!isTokenRegistered[_tokenAddress], "Token already registered");
        require(bytes(_tokenName).length > 0, "Token name cannot be empty");
        require(bytes(_tokenSymbol).length > 0, "Token symbol cannot be empty");
        
        tokenMetrics[_tokenAddress] = TokenMetrics({
            tokenAddress: _tokenAddress,
            tokenName: _tokenName,
            tokenSymbol: _tokenSymbol,
            totalSupply: _totalSupply,
            transactionCount: 0,
            uniqueHolders: 0,
            lastUpdated: block.timestamp,
            isActive: true
        });
        
        isTokenRegistered[_tokenAddress] = true;
        registeredTokens.push(_tokenAddress);
        totalTokensAnalyzed++;
        
        emit TokenRegistered(_tokenAddress, _tokenName, _tokenSymbol, block.timestamp);
    }
    
    /**
     * @dev Record a token transaction for analytics
     * @param _tokenAddress Address of the token
     * @param _from Sender address
     * @param _to Receiver address
     * @param _amount Transaction amount
     * @param _transactionType Type of transaction (transfer, swap, etc.)
     */
    function recordTransaction(
        address _tokenAddress,
        address _from,
        address _to,
        uint256 _amount,
        string memory _transactionType
    ) external tokenExists(_tokenAddress) validAddress(_from) validAddress(_to) {
        require(_amount > 0, "Amount must be greater than zero");
        
        uint256 transactionId = totalTransactionsTracked;
        
        transactions[transactionId] = TransactionData({
            tokenAddress: _tokenAddress,
            from: _from,
            to: _to,
            amount: _amount,
            timestamp: block.timestamp,
            transactionType: _transactionType
        });
        
        tokenTransactionIds[_tokenAddress].push(transactionId);
        totalTransactionsTracked++;
        
        Track unique holders
        if (!hasInteracted[_tokenAddress][_from]) {
            hasInteracted[_tokenAddress][_from] = true;
            tokenMetrics[_tokenAddress].uniqueHolders++;
        }
        if (!hasInteracted[_tokenAddress][_to]) {
            hasInteracted[_tokenAddress][_to] = true;
            tokenMetrics[_tokenAddress].uniqueHolders++;
        }
        
        emit TransactionRecorded(transactionId, _tokenAddress, _from, _to, _amount);
        emit MetricsUpdated(_tokenAddress, tokenMetrics[_tokenAddress].transactionCount, tokenMetrics[_tokenAddress].uniqueHolders, block.timestamp);
    }
    
    /**
     * @dev Create an analytics snapshot for a token
     * @param _tokenAddress Address of the token
     * @param _volume24h 24-hour trading volume
     * @param _avgTransactionSize Average transaction size
     */
    function createSnapshot(
        address _tokenAddress,
        uint256 _volume24h,
        uint256 _avgTransactionSize
    ) external onlyOwner tokenExists(_tokenAddress) {
        uint256 snapshotId = snapshotCounter;
        
        snapshots[snapshotId] = AnalyticsSnapshot({
            snapshotId: snapshotId,
            tokenAddress: _tokenAddress,
            volume24h: _volume24h,
            avgTransactionSize: _avgTransactionSize,
            timestamp: block.timestamp
        });
        
        snapshotCounter++;
        
        emit SnapshotCreated(snapshotId, _tokenAddress, _volume24h, block.timestamp);
    }
    
    /**
     * @dev Get token metrics
     * @param _tokenAddress Address of the token
     * @return TokenMetrics struct containing all metrics
     */
    function getTokenMetrics(address _tokenAddress) external view tokenExists(_tokenAddress) returns (TokenMetrics memory) {
        return tokenMetrics[_tokenAddress];
    }
    
    /**
     * @dev Get transaction details
     * @param _transactionId ID of the transaction
     * @return TransactionData struct containing transaction details
     */
    function getTransaction(uint256 _transactionId) external view returns (TransactionData memory) {
        require(_transactionId < totalTransactionsTracked, "Transaction does not exist");
        return transactions[_transactionId];
    }
    
    /**
     * @dev Get all transaction IDs for a specific token
     * @param _tokenAddress Address of the token
     * @return Array of transaction IDs
     */
    function getTokenTransactions(address _tokenAddress) external view tokenExists(_tokenAddress) returns (uint256[] memory) {
        return tokenTransactionIds[_tokenAddress];
    }
    
    /**
     * @dev Get snapshot details
     * @param _snapshotId ID of the snapshot
     * @return AnalyticsSnapshot struct containing snapshot data
     */
    function getSnapshot(uint256 _snapshotId) external view returns (AnalyticsSnapshot memory) {
        require(_snapshotId < snapshotCounter, "Snapshot does not exist");
        return snapshots[_snapshotId];
    }
    
    /**
     * @dev Get all registered tokens
     * @return Array of registered token addresses
     */
    function getAllTokens() external view returns (address[] memory) {
        return registeredTokens;
    }
    
    /**
     * @dev Get the total number of registered tokens
     * @return Total count of registered tokens
     */
    function getTokenCount() external view returns (uint256) {
        return totalTokensAnalyzed;
    }
    
    /**
     * @dev Update token active status
     * @param _tokenAddress Address of the token
     * @param _isActive New active status
     */
    function updateTokenStatus(address _tokenAddress, bool _isActive) external onlyOwner tokenExists(_tokenAddress) {
        tokenMetrics[_tokenAddress].isActive = _isActive;
        tokenMetrics[_tokenAddress].lastUpdated = block.timestamp;
    }
    
    /**
     * @dev Transfer ownership of the contract
     * @param _newOwner Address of the new owner
     */
    function transferOwnership(address _newOwner) external onlyOwner validAddress(_newOwner) {
        address previousOwner = owner;
        owner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }
    
    /**
     * @dev Get contract statistics
     * @return totalTokens Total number of tokens tracked
     * @return totalTxns Total number of transactions recorded
     * @return totalSnapshots Total number of snapshots created
     */
    function getContractStats() external view returns (uint256 totalTokens, uint256 totalTxns, uint256 totalSnapshots) {
        return (totalTokensAnalyzed, totalTransactionsTracked, snapshotCounter);
    }
}
// 
End
// 
