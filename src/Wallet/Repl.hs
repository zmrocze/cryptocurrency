{-# LANGUAGE GADTs #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE RankNTypes #-}

module Wallet.Repl where

import BlockCreation (OwnedUTXO)
import BlockType (Transaction, TXID, Cent, PublicAddress, Coinbase, BlockReference)
import GHC.Generics (Generic)
import Data.Aeson (ToJSON, FromJSON, eitherDecode, encode)
import Server (readAllMessages, Address, acceptSingleClient)
import qualified Data.ByteString.Lazy as Lazy
import Data.Bifunctor (second)
import Network.Socket (Socket)
import Wallet.Type (Status)
import Client (send)

-- Non-GADT type to transform to and from JSON data. 
data CommandJSON
    = AddCoinJSON  OwnedUTXO
    | AddTransactionJSON  (Either Coinbase Transaction) (Maybe BlockReference)
    | SendTransactionJSON  PublicAddress Cent
    | GetStatusJSON  TXID
    deriving (Generic)

instance ToJSON CommandJSON
instance FromJSON CommandJSON

-- Type for a command to wallet repl. 
data CommandR response where
    AddCoin         :: OwnedUTXO -> CommandR AddCoinResponse
    AddTransaction  :: Either Coinbase Transaction -> Maybe BlockReference -> CommandR AddTransactionResponse
    SendTransaction :: PublicAddress -> Cent -> CommandR SendTransactionResponse
    GetStatus       :: TXID -> CommandR StatusResponse

-- Existentially qualified CommandR type.
data Command = forall r . ToJSON r => Command (CommandR r)

parseCommand :: Lazy.ByteString -> Either String Command
parseCommand = second commandFromJSON . eitherDecode
    where
        commandFromJSON :: CommandJSON -> Command
        commandFromJSON (AddCoinJSON utxo) = Command $ AddCoin utxo
        commandFromJSON (AddTransactionJSON tx blockref) = Command $ AddTransaction tx blockref
        commandFromJSON (SendTransactionJSON pubaddr n) = Command $ SendTransaction pubaddr n
        commandFromJSON (GetStatusJSON txid) = Command $ GetStatus txid

data AddCoinResponse
    = AddCoinSuccess
    | AddCoinFail
    deriving (Generic, Show)

instance ToJSON AddCoinResponse 
instance FromJSON AddCoinResponse 

data AddTransactionResponse
    = AddTransactionSuccess
    | AddTransactionFail
    deriving (Generic, Show)

instance ToJSON AddTransactionResponse 
instance FromJSON AddTransactionResponse 

data SendTransactionResponse
    = SendedTransaction
    | NotEnoughFunds
    | SendTransactionFailure
    deriving (Generic, Show)

instance ToJSON SendTransactionResponse 
instance FromJSON SendTransactionResponse 

data StatusResponse
    = StatusIs TXID Status
    | GetStatusFailure
    deriving (Generic, Show)

instance ToJSON StatusResponse 
instance FromJSON StatusResponse 


readAllCommands :: Socket -> IO [Either String Command]
readAllCommands sock = map parseCommand <$> readAllMessages sock

processMessages :: Socket -> (String -> IO ()) -> (forall r . CommandR r-> IO r) -> IO ()
processMessages sock log f = do 
    cmds <- readAllCommands sock
    tillLeft cmds
    where   
        -- loops till left error 
        tillLeft [] = log "repl: Finished processing."
        tillLeft (Left str : es) = log ("repl: Command decoding error: \n" <> str)
        tillLeft (Right (Command c) : es) = do
            resp <- f c
            send sock $ encode resp
            tillLeft es


serveRepl :: Address -> (String -> IO ()) -> (forall r . CommandR r-> IO r) -> IO ()
serveRepl addr log handler = acceptSingleClient addr log $ \sock ->
    processMessages sock log handler
