{-# LANGUAGE DeriveGeneric #-}
module Wallet.Type where
import BlockType (BlockReference, TXID, Transaction (Transaction), BlockHeader (BlockHeader), Coinbase)
import GHC.Generics (Generic)
import Data.Aeson (ToJSON, FromJSON)

-- Decision: Let's store transactions rather than utxos. We lose less information and its trivial to get utxos from tx.

data Status
    = Validated -- block of td already in fixed  
    | Waiting   -- still not in fixed 
    | Discarded -- optional usage for when we observe tx being thrown from lively.
    -- ^ another option is to use versioning with blockheight 
    deriving (Generic, Show)

instance ToJSON Status
instance FromJSON Status
    

data UpdateStatus
    = Fixed { getBlockRef :: BlockReference }
    | Discard { getBockRef :: BlockReference}


-- 
data StoredTransaction = StoredTransaction {
    txid :: TXID,
    txBlockId :: Maybe BlockReference,
    txData :: Either Coinbase Transaction,
    txStatus :: Status
}

data StoredBlockHeader = StoredBlockHeader {
    blockid :: BlockReference,
    headerData :: BlockHeader
}
