/// <reference path="../test-types.ts"/>

import * as _ from 'lodash';
import assert = require('assert');
import fs = require('fs');
import server = require('../utils/server');
import utils = require('../utils/utils');
import pages = require('../utils/pages');
import pagesFor = require('../utils/pages-for');
import settings = require('../utils/settings');
import make = require('../utils/make');
import logAndDie = require('../utils/log-and-die');
import c = require('../test-constants');
declare let browser: any;

let everyonesBrowsers;
let maria;
let mariasBrowser;
let strangersBrowser;

let data;
let idAddress: IdAddress;
let siteId: any;

const mariasCommentOneOrig = 'mariasCommentOneOrig';
const mariasCommentOneEdited = 'mariasCommentOneEdited';
const mariasCommentTwo = 'mariasCommentTwo';

const localHostname = 'comments-for-e2e-test-embddrft-localhost-8080';
const embeddingOrigin = 'http://e2e-test-embddrft.localhost:8080';
const pageDddSlug = 'emb-cmts-ddd.html';
const pageEeeSlug = 'emb-cmts-eee.html';


describe("emb cmts drafts when not logged in  TyT2ZBKPW048", () => {

  it("initialize people", () => {
    everyonesBrowsers = _.assign(browser, pagesFor(browser));
    mariasBrowser = everyonesBrowsers;
    maria = make.memberMaria();
  });

  it("import a site", () => {
    const site: SiteData = make.forumOwnedByOwen('embddrft', { title: "Emb Cmts Disc Id Test" });
    site.meta.localHostname = localHostname;
    site.settings.allowEmbeddingFrom = embeddingOrigin;
    site.settings.requireVerifiedEmail = false;
    site.settings.mayComposeBeforeSignup = true;
    site.settings.mayPostBeforeEmailVerified = true;
    site.settings.allowGuestLogin = true;
    site.members.push(maria);
    idAddress = server.importSiteData(site);
    siteId = idAddress.id;
  });

  it("create two embedding pages ddd & eee", () => {
    const dir = 'target';
    fs.writeFileSync(`${dir}/${pageDddSlug}`, makeHtml('ddd', '', '#500'));
    fs.writeFileSync(`${dir}/${pageEeeSlug}`, makeHtml('eee', '', '#040'));
    function makeHtml(pageName: string, discussionId: string, bgColor: string): string {
      return utils.makeEmbeddedCommentsHtml({ pageName, discussionId, localHostname, bgColor });
    }
  });

  it("Maria opens embedding page ddd", () => {
    mariasBrowser.go(embeddingOrigin + '/' + pageDddSlug);
  });

  it("Starts writing a reply, when not logged in", () => {
    mariasBrowser.switchToEmbeddedCommentsIrame();
    mariasBrowser.topic.clickReplyToEmbeddingBlogPost();
  });

  it("... writes a comment", () => {
    mariasBrowser.switchToEmbeddedEditorIrame();
    mariasBrowser.editor.editText(mariasCommentOneOrig);
  });


  // ----- Beacon save, first reply

  it("She reloads the page, without posting the comment — this beacon-saves the text", () => {
    mariasBrowser.refresh();
  });

  it("... she starts writing again", () => {
    mariasBrowser.switchToEmbeddedCommentsIrame();
    mariasBrowser.topic.clickReplyToEmbeddingBlogPost();
  });

  it("... the text is still there; it was saved in the browser's sessionStorage", () => {
    mariasBrowser.switchToEmbeddedEditorIrame();
    mariasBrowser.editor.waitForDraftTextToLoad(mariasCommentOneOrig);
  });


  // ----- Drafts are per page

  it("she goes from page ddd to eee", () => {
    let source = mariasBrowser.getSource();
    assert(source.indexOf('ddd') > 0);
    mariasBrowser.go(embeddingOrigin + '/' + pageEeeSlug);
    source = mariasBrowser.getSource();
    assert(source.indexOf('eee') > 0);
  });

  it("... starts replying to page Eee's blog post", () => {
    mariasBrowser.switchToEmbeddedCommentsIrame();
    mariasBrowser.topic.clickReplyToEmbeddingBlogPost();
  });

  it("... now there's no draft — because this is a different page, page Eee", () => {
    mariasBrowser.switchToEmbeddedEditorIrame();
    mariasBrowser.editor.waitForDraftTextToLoad('');
  });

  it("she retunrs to ddd", () => {
    mariasBrowser.go(embeddingOrigin + '/' + pageDddSlug);
    const source = mariasBrowser.getSource();
    assert(source.indexOf('ddd') > 0);
  });

  it("... starts replying again", () => {
    mariasBrowser.switchToEmbeddedCommentsIrame();
    mariasBrowser.topic.clickReplyToEmbeddingBlogPost();
  });

  it("... the draft text loads, again", () => {
    mariasBrowser.switchToEmbeddedEditorIrame();
    mariasBrowser.editor.waitForDraftTextToLoad(mariasCommentOneOrig);
  });

  it("... she edits the reply draft", () => {
    mariasBrowser.editor.editText(mariasCommentOneEdited);
  });


  // ----- Unmount save, first reply

  it("And closes the editor — this unmound-saves the reply", () => {
    mariasBrowser.editor.cancelNoHelp();
  });

  it("She refreshes, and reopens the editor", () => {
    mariasBrowser.refresh();
    mariasBrowser.switchToEmbeddedCommentsIrame();
    mariasBrowser.topic.clickReplyToEmbeddingBlogPost();
  });

  it("... the text is there, edited", () => {
    mariasBrowser.switchToEmbeddedEditorIrame();
    mariasBrowser.editor.waitForDraftTextToLoad(mariasCommentOneEdited);
  });

  it("She clicks Post Reply", () => {
    mariasBrowser.editor.save();
  });

  it("... logs in, to post the comment", () => {
    mariasBrowser.loginDialog.loginWithPasswordInPopup(maria);
  });

  it("The comment is there, as the first reply", () => {
    mariasBrowser.switchToEmbeddedCommentsIrame();
    mariasBrowser.topic.waitForPostNrVisible(c.FirstReplyNr);
    mariasBrowser.topic.assertPostTextMatches(c.FirstReplyNr, mariasCommentOneEdited);
  });


  // ----- Beacon save, subsequent replies

  it("Maria logs out", () => {
    mariasBrowser.metabar.clickLogout();
  });

  it("And starts typing a reply to herself, not logged in", () => {
    mariasBrowser.switchToEmbeddedCommentsIrame();
    mariasBrowser.topic.clickReplyToPostNr(c.FirstReplyNr);
    mariasBrowser.switchToEmbeddedEditorIrame();
    mariasBrowser.editor.editText(mariasCommentTwo);
  });

  it("Refreshs the page — this beacon saves", () => {
    mariasBrowser.refresh();
  });

  it("She starts replying to herself again", () => {
    mariasBrowser.switchToEmbeddedCommentsIrame();
    mariasBrowser.topic.clickReplyToPostNr(c.FirstReplyNr);
  });

  it("... the text is there, it got beacon-saved", () => {
    mariasBrowser.switchToEmbeddedEditorIrame();
    mariasBrowser.editor.waitForDraftTextToLoad(mariasCommentTwo);
  });


  // ----- Drafts are per post

  it("She closes the editor", () => {
    mariasBrowser.editor.cancelNoHelp();
  });

  it("And clicks Reply, to the blog post (but not her own comment)", () => {
    mariasBrowser.switchToEmbeddedCommentsIrame();
    mariasBrowser.topic.clickReplyToEmbeddingBlogPost();
  });

  it("Now no draft text loads, because the draft is for a reply to Marias's comment", () => {
    mariasBrowser.switchToEmbeddedEditorIrame();
    mariasBrowser.editor.waitForDraftTextToLoad('');
  });

});

