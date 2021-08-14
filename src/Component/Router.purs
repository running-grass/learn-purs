module LinkNote.Component.Router where


import Prelude

import Control.Promise (Promise, toAffE)
import Data.Either (hush)
import Data.Maybe (Maybe(..), fromMaybe)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff.Class (class MonadAff)
import Halogen (liftEffect)
import Halogen as H
import Halogen.HTML as HH
import IPFS (IPFS)
import LinkNote.Component.HTML.Header (header)
import LinkNote.Component.Navigate (class Navigate, navigate)
import LinkNote.Data.Route (Route(..), routeCodec)
import LinkNote.Data.Setting (IPFSApiAddress(..), IPFSInstanceType(..))
import LinkNote.Page.Home (Note, File)
import LinkNote.Page.Home as Home
import LinkNote.Page.Setting as Setting
import LinkNote.Page.TopicList as TopicList
import Routing.Duplex as RD
import Routing.Hash (getHash)
import RxDB.Type (RxCollection)
import Type.Proxy (Proxy(..))

type OpaqueSlot slot = forall query. H.Slot query Void slot



foreign import getGlobalIPFS :: (forall x. x -> Maybe x) 
                                -> (forall x. Maybe x) 
                                -> String 
                                -> Effect (Promise (Maybe IPFS))

getGlobalIPFSA :: String -> Aff (Maybe IPFS)
getGlobalIPFSA addr = toAffE $ getGlobalIPFS Just Nothing addr

getIpfsAddrByType :: IPFSInstanceType -> String
getIpfsAddrByType Unused = "none"
getIpfsAddrByType WindowIPFS = "window"
getIpfsAddrByType JsIPFS = "js"
getIpfsAddrByType LocalIPFS = "http://127.0.0.1:5001/"
getIpfsAddrByType BraveBrowser = "http://127.0.0.1:45005/"
getIpfsAddrByType (CustomAPI  (IPFSApiAddress addr)) = addr

currentIpfs :: IPFSInstanceType
currentIpfs = BraveBrowser

data Query a
  = Navigate Route a

type State = { 
    route :: Maybe Route,
    coll :: RxCollection Note, 
    collFile :: RxCollection File,
    ipfs :: Maybe IPFS 
  }

type Input = { 
  coll :: RxCollection Note, 
  collFile :: RxCollection File,
  ipfs :: Maybe IPFS 
  }

data Action
  = Init
  | InitIPFS

type ChildSlots =
  ( home :: OpaqueSlot Unit
  , setting :: OpaqueSlot Unit
  , topicList :: OpaqueSlot Unit
  )

initialState :: Input -> State
initialState input = { 
  route: Nothing,
  coll : input.coll,
  collFile : input.collFile,
  ipfs : input.ipfs
  }

component
  :: forall m
   . MonadAff m
  => Navigate m
  => H.Component Query Input Void m
component = H.mkComponent
  { initialState: initialState
  , render
  , eval: H.mkEval $ H.defaultEval
      { handleQuery = handleQuery
      , handleAction = handleAction
      , initialize = Just Init
      }
  }
  where
  handleAction :: Action -> H.HalogenM State Action ChildSlots Void m Unit
  handleAction = case _ of
    Init -> do
      -- first we'll get the route the user landed on
      initialRoute <- hush <<< (RD.parse routeCodec) <$> liftEffect getHash
      -- then we'll navigate to the new route (also setting the hash)
      H.modify_ _ { route = initialRoute }
      navigate $ fromMaybe Home initialRoute
      handleAction InitIPFS
    InitIPFS -> do
      let addr = getIpfsAddrByType currentIpfs
      ipfs <- H.liftAff $ getGlobalIPFSA addr
      H.modify_ _ { ipfs = ipfs }

  handleQuery :: forall a. Query a -> H.HalogenM State Action ChildSlots Void m (Maybe a)
  handleQuery = case _ of
    Navigate dest a -> do
      { route } <-  H.get
      -- don't re-render unnecessarily if the route is unchanged
      when (route /= Just dest) do 
        H.modify_ _ { route = Just dest }
      pure (Just a)

  render :: State -> H.ComponentHTML Action ChildSlots m
  render { route, ipfs, coll, collFile  } = HH.div_ [
    header route,
    case route of
      Just r -> case r of
        Home ->
          HH.slot_ (Proxy :: _ "home") unit Home.component {ipfs, coll, collFile}
        Setting ->
          -- HH.div_ [ HH.text "I will be a setting page." ]
          HH.slot_ (Proxy :: _ "setting") unit Setting.component {  ipfsInstanceType: JsIPFS }  
        TopicList ->
          HH.slot_ (Proxy :: _ "topicList") unit TopicList.component {  ipfsInstanceType: JsIPFS }  
        _ -> HH.div_ [ HH.text "404页面" ]
      Nothing ->
        HH.div_ [ HH.text "Oh yeah! You get a 404 page." ]
  ]
