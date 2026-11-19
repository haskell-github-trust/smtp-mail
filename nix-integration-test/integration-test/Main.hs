{-# LANGUAGE OverloadedStrings #-}
module Main where

import Network.Mail.SMTP hiding (simpleMail)
import Network.Mail.Mime (simpleMail, Mail(..))
import System.Environment as Env
import Test.Hspec
import Test.Hspec.Expectations

from       = Address Nothing "integration-test-smtp-mail@acme.test"
to         = Address (Just "alice") "alice@acme.test"
subject    = "Test"
body       = "Test Mail Body Part"
html       = "<h1>This Test succeeded!</h1>"

createMail label = simpleMail to from (subject <> " " <> label) body html []

host = "acme.test"

doPlainSmtp = createMail "Plain" >>= sendMail host
doTlsSmtp = createMail "TLS" >>= sendMailTLS host
doSTARTTLS = createMail "STARTTLS" >>= sendMailSTARTTLS host
doBcc = do
  mail <- createMail "Bcc"
  sendMail host mail { mailBcc = [Address (Just "bob") "bob@acme.test"] }

main :: IO ()
main = hspec $ do
  describe "Sending a mail should succeed" $ do
    it "using plain smtp" $ do
      doPlainSmtp `shouldReturn` ()
    it "using smtps" $ do
      doTlsSmtp `shouldReturn` ()
    it "using STARTTLS" $ do
      doSTARTTLS `shouldReturn` ()
    it "using Bcc" $ do
      doBcc `shouldReturn` ()
