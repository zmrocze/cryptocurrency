{-# LANGUAGE ScopedTypeVariables #-}
module BlocksValidationTest where

import BlockType
import ArbitraryBlock
import Test.QuickCheck
import qualified Data.Map as Map
import BlockValidation (UTXOPool(..), validateBlockTransactions,UTXO (UTXO))
import Data.List (foldl')
import BlockCreation (OwnedUTXO(OwnedUTXO), ByteStringJSON (ByteStringJSON), Keys)
import qualified Data.Aeson as Aeson
import Data.ByteString (ByteString)


foldBlockTransactions :: [Block] -> Maybe UTXOPool
foldBlockTransactions = foldl' f (Just (UTXOPool Map.empty))
    where
        f (Just (UTXOPool utxos)) block =
            case validateBlockTransactions (UTXOPool utxos) block of
                (True, newUtxos) -> Just newUtxos
                (False, _ )      -> Nothing
        f Nothing _ = Nothing

-- Checks whether UTXOs accumulated by folding validateBlockTransactions on a list of blocks
-- are the same that the ones arbitraryBlockchain accumulates in the process of generating blocks. 
prop_UTXOPoolCorrect :: BlockchainWithState -> Bool
prop_UTXOPoolCorrect (BlockchainWithState utxos blocks genesis) =
    case foldBlockTransactions (reverse blocks) of
        Just (UTXOPool utxoPool) -> 
            -- all utxoPool contains all utxos and theyre the same size, then utxoPool == utxos
            all (\(OwnedUTXO (UTXO txid vout _) _) -> 
                (txid, vout) `Map.member` utxoPool) utxos
            && Map.size utxoPool == length utxos
        Nothing -> False


prop_BlockchainToJSONFromJSON :: BlockchainWithState -> Bool
prop_BlockchainToJSONFromJSON (BlockchainWithState utxos blocks genesis) =
       (Aeson.decode' . Aeson.encode) utxos == Just utxos
    && (Aeson.decode' . Aeson.encode) blocks == Just blocks
    && (Aeson.decode' . Aeson.encode) genesis == Just genesis

prop_TransactionsToJSONFromJSON :: BlockchainWithState -> Bool
prop_TransactionsToJSONFromJSON (BlockchainWithState utxos blocks genesis) =
    let txs = concatMap transactions blocks
    in all 
        (\tx -> (Aeson.decode' . Aeson.encode) tx == Just tx)
        txs


-- prop_ByteStringToJSONFromJSON :: ByteString -> Bool
-- prop_ByteStringToJSONFromJSON b =
--        let (mb :: Maybe ByteStringJSON) = (Aeson.decode' . Aeson.encode) (ByteStringJSON b)
--        in case mb of 
--            Nothing -> False
--            Just (ByteStringJSON b') -> b == b'

-- prop_KeysToJSONFromJSON :: Keys -> Bool
-- prop_KeysToJSONFromJSON keys = 
--     (Aeson.decode' . Aeson.encode) keys == Just keys
