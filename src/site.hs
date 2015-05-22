--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid ((<>))
import           Hakyll
import           MathCompiler
import           Control.Monad (liftM)


--------------------------------------------------------------------------------
main :: IO ()
main = hakyll $ do
    paginate <- buildPaginateWith pageGrouper "posts/*" makePageId

    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match "js/*" $ do
        route  idRoute
        compile copyFileCompiler

    match "posts/*" $ do
        route $ setExtension "html"
        compile $ mathCompiler
            >>= saveSnapshot "content"
            >>= loadAndApplyTemplate "templates/post.html"    postContext
            >>= loadAndApplyTemplate "templates/default.html" postContext
            >>= relativizeUrls

    match "projects/*" $ do
      route $ setExtension "html"
      compile $ mathCompiler
            >>= loadAndApplyTemplate "templates/project.html" postContext
            >>= relativizeUrls

    paginateRules paginate $ \pageNum pattern -> do
      route idRoute
      compile $ do
        posts <- recentFirst =<< loadAllSnapshots pattern "content"
        let postPreviewContext =
                      listField "posts" previewContext (return posts)
                      <> (paginateContext paginate pageNum)
                      <> constField "title" "Posts"
                      <> defaultContext
        makeItem ""
          >>= loadAndApplyTemplate "templates/post-previews.html" postPreviewContext
          >>= loadAndApplyTemplate "templates/default.html" postPreviewContext
          >>= relativizeUrls

    create ["projects.html"] $ do
        route idRoute
        compile $ do
            projects <- recentFirst =<< loadAll "projects/*"
            let projectContext =
                    listField "projects" postContext (return projects) <>
                    constField "title" "Projects" <>
                    defaultContext

            makeItem ""
              >>= loadAndApplyTemplate "templates/projects.html" projectContext
              >>= loadAndApplyTemplate "templates/default.html" projectContext
              >>= relativizeUrls



    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let archiveContext =
                    listField "posts" postContext (return posts) <>
                    constField "title" "Archives" <>
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveContext
                >>= loadAndApplyTemplate "templates/default.html" archiveContext
                >>= relativizeUrls

    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- fmap (take 5) . recentFirst =<< loadAllSnapshots "posts/*" "content"
            let postPreviewContext =
                    listField "posts" previewContext (return posts)
                    <> constField "title" "Posts"
                    <> defaultContext

            getResourceBody
                >>= applyAsTemplate postPreviewContext
                >>= loadAndApplyTemplate "templates/default.html" postPreviewContext
                >>= relativizeUrls

    match "templates/*" $ compile templateCompiler

--------------------------------------------------------------------------------
postContext :: Context String
postContext =
    dateField "date" "%B %e, %Y" <>
    defaultContext

previewContext = teaserField "teaser" "content" <> postContext

pageGrouper :: MonadMetadata m => [Identifier] -> m [[Identifier]]
pageGrouper ids = (liftM (paginateEvery 5) . sortRecentFirst) ids

makePageId :: PageNumber -> Identifier
makePageId pageNum = fromFilePath $ "blog/page" ++ (show pageNum) ++ ".html"
