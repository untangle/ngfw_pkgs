function RkioskBrowserStartup()
{
  gBrowser = document.getElementById("content");

  window.tryToClose = WindowIsClosing;

  var uriToLoad = null;
  // Check for window.arguments[0]. If present, use that for uriToLoad.
  if ("arguments" in window && window.arguments.length >= 1 && window.arguments[0])
    uriToLoad = window.arguments[0];

  gIsLoadingBlank = uriToLoad == "about:blank";

  if (!gIsLoadingBlank)
    prepareForStartup();

//@line 607 "/cygdrive/c/builds/tinderbox/Fx-Mozilla1.8/WINNT_5.2_Depend/mozilla/browser/base/content/browser.js"
  // only load url passed in when we're not page cycling

  if (uriToLoad && !gIsLoadingBlank) {
    if ("arguments" in window && window.arguments.length >= 3)
      loadURI(uriToLoad, window.arguments[2], null);
    else
      loadOneOrMoreURIs(uriToLoad);
  }

//@line 617 "/cygdrive/c/builds/tinderbox/Fx-Mozilla1.8/WINNT_5.2_Depend/mozilla/browser/base/content/browser.js"

  var sidebarSplitter;
  if (window.opener && !window.opener.closed) {
    if (window.opener.gFindMode == FIND_NORMAL) {
      var openerFindBar = window.opener.document.getElementById("FindToolbar");
      if (openerFindBar && !openerFindBar.hidden)
        openFindBar();
    }

    var openerSidebarBox = window.opener.document.getElementById("sidebar-box");
    // The opener can be the hidden window too, if we're coming from the state
    // where no windows are open, and the hidden window has no sidebar box.
    if (openerSidebarBox && !openerSidebarBox.hidden) {
      var sidebarBox = document.getElementById("sidebar-box");
      var sidebarTitle = document.getElementById("sidebar-title");
      sidebarTitle.setAttribute("value", window.opener.document.getElementById("sidebar-title").getAttribute("value"));
      sidebarBox.setAttribute("width", openerSidebarBox.boxObject.width);
      var sidebarCmd = openerSidebarBox.getAttribute("sidebarcommand");
      sidebarBox.setAttribute("sidebarcommand", sidebarCmd);
      sidebarBox.setAttribute("src", window.opener.document.getElementById("sidebar").getAttribute("src"));
      gMustLoadSidebar = true;
      sidebarBox.hidden = false;
      sidebarSplitter = document.getElementById("sidebar-splitter");
      sidebarSplitter.hidden = false;
      document.getElementById(sidebarCmd).setAttribute("checked", "true");
    }
  }
  else {
    var box = document.getElementById("sidebar-box");
    if (box.hasAttribute("sidebarcommand")) {
      var commandID = box.getAttribute("sidebarcommand");
      if (commandID) {
        var command = document.getElementById(commandID);
        if (command) {
          gMustLoadSidebar = true;
          box.hidden = false;
          sidebarSplitter = document.getElementById("sidebar-splitter");
          sidebarSplitter.hidden = false;
          command.setAttribute("checked", "true");
        }
        else {
          // Remove the |sidebarcommand| attribute, because the element it 
          // refers to no longer exists, so we should assume this sidebar
          // panel has been uninstalled. (249883)
          box.removeAttribute("sidebarcommand");
        }
      }
    }
  }

  // Certain kinds of automigration rely on this notification to complete their
  // tasks BEFORE the browser window is shown.
  var obs = Components.classes["@mozilla.org/observer-service;1"].getService(Components.interfaces.nsIObserverService);
  obs.notifyObservers(null, "browser-window-before-show", "");

  // Set a sane starting width/height for all resolutions on new profiles.
  if (!document.documentElement.hasAttribute("width")) {
    var defaultWidth = 994, defaultHeight;
    if (screen.availHeight <= 600) {
      document.documentElement.setAttribute("sizemode", "maximized");
      defaultWidth = 610;
      defaultHeight = 450;
    }
    else {
      // Create a narrower window for large or wide-aspect displays, to suggest
      // side-by-side page view.
      if ((screen.availWidth / 2) >= 800)
        defaultWidth = (screen.availWidth / 2) - 20;
      defaultHeight = screen.availHeight - 10;
//@line 701 "/cygdrive/c/builds/tinderbox/Fx-Mozilla1.8/WINNT_5.2_Depend/mozilla/browser/base/content/browser.js"
    }
    document.documentElement.setAttribute("width", defaultWidth);
    document.documentElement.setAttribute("height", defaultHeight);
  }
  setTimeout(RKioskdelayedStartup, 0);
}

function RKioskdelayedStartup()
{
  var os = Components.classes["@mozilla.org/observer-service;1"].getService(Components.interfaces.nsIObserverService);
  os.addObserver(gSessionHistoryObserver, "browser:purge-session-history", false);
  os.addObserver(gXPInstallObserver, "xpinstall-install-blocked", false);
  os.addObserver(gXPInstallObserver, "xpinstall-install-edit-prefs", false);
  os.addObserver(gXPInstallObserver, "xpinstall-install-edit-permissions", false);
  os.addObserver(gMissingPluginInstaller, "missing-plugin", false);

  gPrefService = Components.classes["@mozilla.org/preferences-service;1"]
                           .getService(Components.interfaces.nsIPrefBranch);
  BrowserOffline.init();
  
  if (gURLBar && document.documentElement.getAttribute("chromehidden").indexOf("toolbar") != -1) {
    gURLBar.setAttribute("readonly", "true");
    gURLBar.setAttribute("enablehistory", "false");
  }

  if (gIsLoadingBlank)
    prepareForStartup();

  if (gURLBar)
    gURLBar.addEventListener("dragdrop", URLBarOnDrop, true);

  // loads the services
  initServices();
  initBMService();
  gBrowser.addEventListener("pageshow", function(evt) { setTimeout(pageShowEventHandlers, 0, evt); }, true);

  window.addEventListener("keypress", ctrlNumberTabSelection, false);

  if (gMustLoadSidebar) {
    var sidebar = document.getElementById("sidebar");
    var sidebarBox = document.getElementById("sidebar-box");
    sidebar.setAttribute("src", sidebarBox.getAttribute("src"));
  }

  initFindBar();

  // add bookmark options to context menu for tabs
  addBookmarkMenuitems();
  // now load bookmarks
  BMSVC.readBookmarks();
  var bt = document.getElementById("bookmarks-ptf");
  if (bt) {
    var btf = BMSVC.getBookmarksToolbarFolder().Value;
    bt.ref = btf;
    document.getElementById("bookmarks-chevron").ref = btf;
    bt.database.AddObserver(BookmarksToolbarRDFObserver);
  }
  window.addEventListener("resize", BookmarksToolbar.resizeFunc, false);
  document.getElementById("PersonalToolbar")
          .controllers.appendController(BookmarksMenuController);

  // called when we go into full screen, even if it is
  // initiated by a web page script
  window.addEventListener("fullscreen", onFullScreen, false);

  var element;
  if (gIsLoadingBlank && gURLBar && !gURLBar.hidden && !gURLBar.parentNode.parentNode.collapsed)
    element = gURLBar;
  else
    element = content;

  // This is a redo of the fix for jag bug 91884
  var ww = Components.classes["@mozilla.org/embedcomp/window-watcher;1"]
                     .getService(Components.interfaces.nsIWindowWatcher);
  if (window == ww.activeWindow) {
    element.focus();
  } else {
    // set the element in command dispatcher so focus will restore properly
    // when the window does become active
    if (element instanceof Components.interfaces.nsIDOMWindow) {
      document.commandDispatcher.focusedWindow = element;
      document.commandDispatcher.focusedElement = null;
    } else if (element instanceof Components.interfaces.nsIDOMElement) {
      document.commandDispatcher.focusedWindow = element.ownerDocument.defaultView;
      document.commandDispatcher.focusedElement = element;
    }
  }

  SetPageProxyState("invalid");

  var toolbox = document.getElementById("navigator-toolbox");
  toolbox.customizeDone = BrowserToolboxCustomizeDone;

  // Set up Sanitize Item
  gSanitizeListener = new SanitizeListener();

  var pbi = gPrefService.QueryInterface(Components.interfaces.nsIPrefBranchInternal);

  // Enable/Disable Form Fill
  gFormFillPrefListener = new FormFillPrefListener();
  pbi.addObserver(gFormFillPrefListener.domain, gFormFillPrefListener, false);
  gFormFillPrefListener.toggleFormFill();

  // Enable/Disable URL Bar Auto Fill
  gURLBarAutoFillPrefListener = new URLBarAutoFillPrefListener();
  pbi.addObserver(gURLBarAutoFillPrefListener.domain, gURLBarAutoFillPrefListener, false);

  // Enable/Disbale auto-hide tabbar
  gAutoHideTabbarPrefListener = new AutoHideTabbarPrefListener();
  pbi.addObserver(gAutoHideTabbarPrefListener.domain, gAutoHideTabbarPrefListener, false);

  pbi.addObserver(gHomeButton.prefDomain, gHomeButton, false);
  gHomeButton.updateTooltip();

  gClickSelectsAll = gPrefService.getBoolPref("browser.urlbar.clickSelectsAll");

  clearObsoletePrefs();

//@line 897 "/cygdrive/c/builds/tinderbox/Fx-Mozilla1.8/WINNT_5.2_Depend/mozilla/browser/base/content/browser.js"
  // Perform default browser checking (after window opens).
  var shell = getShellService();
  if (shell) {
    var shouldCheck = shell.shouldCheckDefaultBrowser;
    if (shouldCheck && !shell.isDefaultBrowser(true)) {
      var brandBundle = document.getElementById("bundle_brand");
      var shellBundle = document.getElementById("bundle_shell");

      var brandShortName = brandBundle.getString("brandShortName");
      var promptTitle = shellBundle.getString("setDefaultBrowserTitle");
      var promptMessage = shellBundle.getFormattedString("setDefaultBrowserMessage",
                                                         [brandShortName]);
      var checkboxLabel = shellBundle.getFormattedString("setDefaultBrowserDontAsk",
                                                         [brandShortName]);
      const IPS = Components.interfaces.nsIPromptService;
      var ps = Components.classes["@mozilla.org/embedcomp/prompt-service;1"]
                                                .getService(IPS);
      var checkEveryTime = { value: shouldCheck };
      var rv = ps.confirmEx(window, promptTitle, promptMessage,
                            (IPS.BUTTON_TITLE_YES * IPS.BUTTON_POS_0) +
                            (IPS.BUTTON_TITLE_NO * IPS.BUTTON_POS_1),
                            null, null, null, checkboxLabel, checkEveryTime);
      if (rv == 0)
        shell.setDefaultBrowser(true, false);
      shell.shouldCheckDefaultBrowser = checkEveryTime.value;
    }
  } else {
    // We couldn't get the shell service; go hide the mail toolbar button.
    var mailbutton = document.getElementById("mail-button");
    if (mailbutton)
      mailbutton.hidden = true;
  }
//@line 930 "/cygdrive/c/builds/tinderbox/Fx-Mozilla1.8/WINNT_5.2_Depend/mozilla/browser/base/content/browser.js"

  // BiDi UI
  gBidiUI = isBidiEnabled();
  if (gBidiUI) {
    document.getElementById("documentDirection-separator").hidden = false;
    document.getElementById("documentDirection-swap").hidden = false;
    document.getElementById("textfieldDirection-separator").hidden = false;
    document.getElementById("textfieldDirection-swap").hidden = false;
  }

  FeedHandler.init();
// For store, we don't want full screen:
//  BrowserFullScreen();	
}
