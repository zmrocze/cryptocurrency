module Main where 
    
import Wallet.Wallet
import Node (LoggingMode(ToStdout))

nodeConfig = NodeConfig {
    port = "5024",
    loggingMode = ToStdout,
    peersFilepath = "app/data/peers.json"
}

blockchainConfig = _

main = runWallet _