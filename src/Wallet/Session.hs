module Wallet.Session where

import qualified Hasql.Transaction as DBTransaction
import BlockType (BlockReference, TXID, BlockHeader, coinbaseOutputs, outputs)
import Wallet.Type (Status (Validated), StoredTransaction (StoredTransaction))
import qualified Hasql.Transaction as Transaction
-- import qualified Wallet.Statement (selectTxIdByBlock)
import qualified Data.Vector as V
import qualified Wallet.Statement as Statement
import Hashing (shash256)
import qualified Hasql.Session as Session
import Data.Int (Int64, Int32)
import qualified Codec.Crypto.RSA as RSA
import qualified Data.Aeson as Aeson
import BlockCreation (OwnedUTXO(OwnedUTXO), Keys (Keys))
import BlockValidation (UTXO(UTXO))

-- TODO: if Session unused, rename to session

updateTxStatusMany :: Status -> V.Vector TXID -> Transaction.Transaction ()
updateTxStatusMany status txids = Transaction.statement (status, txids) Statement.updateTxStatusMany 


-- Select transactions with given blockRefence, change statuses to status for the ones that predicate evaluates true.
updateStatusByBlockSelected :: BlockReference -> (TXID -> Bool) -> Status -> DBTransaction.Transaction ()
updateStatusByBlockSelected blockref pred status = do 
    txids <- Transaction.statement blockref Statement.selectTxIdByBlock
    updateTxStatusMany Validated (V.filter pred txids)

updateTxStatusByBlock :: 
    Status -> BlockReference -> Transaction.Transaction Int64 
updateTxStatusByBlock status blockRef = Transaction.statement (status, blockRef) Statement.updateTxStatusByBlock

addFixedBlockHeader :: BlockHeader -> DBTransaction.Transaction ()
addFixedBlockHeader blockHeader = Transaction.statement (shash256 $ Right blockHeader, blockHeader) Statement.addFixedBlockHeader

selectFixedCount :: Session.Session Int64
selectFixedCount = Session.statement () Statement.selectFixedCount

insertTransaction :: StoredTransaction -> Session.Session ()
insertTransaction (StoredTransaction txid blockref etx status) = 
    Session.statement 
        (txid, blockref, either Aeson.toJSON Aeson.toJSON etx, status, either (const True) (const False) etx)
        Statement.insertTransaction   

insertOwnedKeys :: TXID -> Int32 -> RSA.PublicKey -> RSA.PrivateKey ->  Session.Session ()
insertOwnedKeys txid vout pub priv = Session.statement (txid, vout, pub, priv) Statement.insertOwnedKeys

insertOwnedUTXO :: OwnedUTXO -> Session.Session ()
insertOwnedUTXO (OwnedUTXO (UTXO txid vout _) (Keys pub priv)) = insertOwnedKeys txid (fromInteger vout) pub priv

selectStatus :: TXID -> Session.Session Status
selectStatus txid = Session.statement txid Statement.selectStatus 

-- selectOwnedByStatus :: (Status -> Session.Session
--                        (V.Vector
--                           (TXID, Int32, RSA.PublicKey, RSA.PrivateKey, Aeson.Value, Bool)))
selectOwnedByStatus :: Status -> Session.Session (V.Vector OwnedUTXO)
selectOwnedByStatus status = V.map makeOwnedUTXO <$> Session.statement status Statement.selectOwnedByStatus 
    where 
        makeOwnedUTXO (txid, vout, pub, priv, json, isCoinbase) =
            -- ! Here we use partial functions assuming correct db data that is:
            --   - vout is reference to existing index in outputs list
            --   - json is correct value for coinbase/transaction consistent with isCoinbase
            let Aeson.Success output =
                    if isCoinbase then
                        (!! fromEnum vout) . coinbaseOutputs <$> Aeson.fromJSON json
                    else 
                        (!! fromEnum vout) . outputs         <$> Aeson.fromJSON json
                        
                in OwnedUTXO (UTXO txid (toInteger vout) output) (Keys pub priv)


updateBlockRef :: BlockReference -> V.Vector TXID -> Session.Session Int64
updateBlockRef blockRef txids = Session.statement (blockRef, txids) Statement.updateBlockRef