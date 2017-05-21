# Weechat-url-hinter

Weechat url hinter is a plugin that open a url on weehcat buffer without touching mouse.

This plugin is the Ubuntu-friendly version.

# Requirement

* Weechat (with ruby)

# Usage

1. Type `/url_hinter` command on the input buffer of Weechat.
2. Then, this plugin searches url strings such as **http://...** or **https://...**
3. If urls are found, they are highlighted and give hint key to the url.
4. When you type a hint key, open the url related to hint key in your default browser.
5. You can cancel the hint mode to retype `/url_hinter` in the hint mode.

## Option

Url hinter has two options.

### 1. first

`/url_hinter first` searches a url that appears first on the current buffer, and then
open the url immediately without entering the hint mode.

### 2. continuous

`/url_hinter continuous` is continuous hint mode. If you have been typed a hint
key, but you'll still stay in the hint mode. You can type a hint key continuous.
And then, all selected urls is opend in browser by typing the enter key.
