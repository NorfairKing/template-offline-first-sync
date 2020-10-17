{-# LANGUAGE OverloadedStrings #-}

module Template.API.Server where

import Control.Monad.Logger
import Control.Monad.Reader
import Database.Persist
import Database.Persist.Sql
import Database.Persist.Sqlite
import Network.Wai as Wai
import Network.Wai.Handler.Warp as Warp
import Servant
import Servant.Auth.Server
import Servant.Server
import Servant.Server.Generic
import Template.API as API
import Template.API.Server.Env
import Template.API.Server.Handler

templateAPIServer :: IO ()
templateAPIServer = do
  runStderrLoggingT $ withSqlitePool "template.sqlite3" 1 $ \pool -> do
    runSqlPool (runMigrationQuiet migrateAll) pool
    liftIO $ do
      jwk <- generateKey
      let serverEnv =
            Env
              { envConnectionPool = pool,
                envCookieSettings = defaultCookieSettings,
                envJWTSettings = defaultJWTSettings jwk
              }
      Warp.run 8000 $ templateAPIServerApp serverEnv

templateAPIServerApp :: Env -> Wai.Application
templateAPIServerApp env = genericServeT (flip runReaderT env) templateHandlers

templateHandlers :: TemplateRoutes (AsServerT H)
templateHandlers =
  TemplateRoutes
    { postRegister = handlePostRegister,
      postLogin = handlePostLogin
    }
