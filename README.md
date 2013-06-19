backtoweb
=========

Backtoweb is a simple web framework for Objective-C developer.
It may be used to create web services and websites.
It uses a simple handlers mechanism which map a URL path to an Objective-C block.

In the following example, we are mapping `http://mywebsite/hello/world` to a block which outputs a single text line.


``` 

@implementation HelloWorldHandler
+(void)initializeHandlers:(FCHandlerManager*)handlerManager
{
    [handlerManager
        addHandler:^BOOL(FCURLRequest *request, FCResponseStream *responseStream, NSMutableDictionary* context)
        {
            [responseStream writeString:@"Hello world !"];

            return NO; //do not try to find another handler
        }
     forLiteralPath:@"/hello/world" pathType:FCPathTypeURLPath priority:FCHandlerPriorityNormal];
}
@end 

```

Check also the following sample:

* the 'http://localhost/hello/vars' sample to see request parameters 
* the 'http://localhost/img' sample to understand how to output a PNG image.


Intro
-----

The current version of the framework will let you test server-side Objective-C using the apache web server integrated in Mac OSX.
It was tested with OSX Mountain Lion.


Installation
------------
The installation process described here is for development purpose only.
If you plan to use the framework in production, you should know how to securely configure the Apache Webserver.
If you don't know (or don't want to know) how to configure Apache, note that we may provide a shared hosting offer based on this framework in the future. 
It is not ready yet, but you can [contact us](mailto:depsys@depsys.fr) if you are interested.


### 1. Install mod_fastcgi
Sadly, OSX Apache Webserver does not come with fastcgi installed

We are using this [homebrew formulae](https://github.com/Homebrew/homebrew-apache) to install it.

```
brew install https://raw.github.com/Homebrew/homebrew-apache/master/mod_fastcgi.rb
```

A common problem with this formulae is :

In that case, use the command and retry the brew install ...

```bash
$ [ "$(sw_vers -productVersion | sed 's/^\(10\.[0-9]\).*/\1/')" = "10.8" ] && bash -c "[ -d /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain ] && sudo bash -c 'cd /Applications/Xcode.app/Contents/Developer/Toolchains/ && ln -vs XcodeDefault.xctoolchain OSX10.8.xctoolchain' || sudo bash -c 'mkdir -vp /Applications/Xcode.app/Contents/Developer/Toolchains/OSX10.8.xctoolchain/usr && cd /Applications/Xcode.app/Contents/Developer/Toolchains/OSX10.8.xctoolchain/usr && ln -vs /usr/bin'"
```

If you don't have homebrew installed or if you want to know more about the toolchain problem,
just check [this page](https://github.com/Homebrew/homebrew-apache).

Alternatively, if you know what you're doing, you can build mod_fastcgi.so from the [source code](http://www.fastcgi.com/dist/fcgi.tar.gz).


### 2. Change Apache Web Server config

Copy the file `httpd-b2w.conf` into the directory `/etc/apache2/other/`.

For example :
```
sudo cp ~/Downloads/backtoweb-master/tools/apache2/httpd-b2w.conf /etc/apache2/other/
```

This file will make Apache load the mod_fastcgi module.
It will also redirects 'directory' requests to our fastcgi app (everything not ending with a file extension).

#### Remark
If you already use the OSX integrated web server for another purpose, please review the config file before using it.
The config file contains a hardcoded path to the mod_fastcgi.so module, so you might want to change it if you haven't use homebrew at step 1.

### 3. Open the backtoweb workspace with Xcode.
### 4. Build and run (with the default scheme 'Apache Debug on dev machine')
Your admin password will be asked twice:
* for copying the built files to the Webserver folder.
* to run the debugger as root in order to attach it to the fastcgi process.

#### Caveats and Security concerns:
An helper tool called CopyHelper.app is used to copy the files.
You will give admin right to this helper by entering your password.
Xcode custom build steps communicate with this process via URL scheme. This has two caveats:
* A lot of 'open' process will be created and left hanging there until you kill CopyHelper.
* Any program can use this app to copy file with admin right.

To mitigate the second problem, copy is limited to the /Library/WebServer destination.
URL schemes are accepted only from the open process (therefore they can not be open via a link in Safari). 

### 5. Go to http://localhost/hello/world with your favorite browser.
#### Put a breakpoint in HelloWorldHandler.m, refresh your browser page and debug !


How does it works
-----------------

### 1. FastCGI

From your browser to the objective-C code :
Browser ----send request----> Apache Webserver ---pass request---> mod_fastcgi.so ---launch and pass request---> fastcgiapp.fcgi ---load and pass request---> HelloWorldHandler.bundle 
and then back using pretty much the same path.

Once executed, the fastcgiapp.fcgi exec will stay in memory and mod_fastcgi will pass requests using sockets (see www.fastcgi.com).

### 2. Handlers bundles and frameworks.

The Xcode workspace comes with an helper app called CopyHelpers.app which will ask root permissions in order to create folders and copy files.
The resulting arborescence is:

```
/Library/WebServer
    |
    |
    Documents  (Default OSX folder for documents)
         <Your static html and image files>
    |
    |
 	CGI-Executables  (Default OSX folder for CGI executables)
 	     fastcgiapp.fcgi
 	|
 	|
 	handlers      (This is where all the bundles will be copied)
 	     HelloWorldHandler.bundle
 	|
 	|
    frameworks    (This is where all the frameworks will be copied)
         backtoweb.framework
         Lumberjack.framework

```

In order for the help app to do its magic, you need to use the 'Apche Debug on dev machine' scheme in Xcode.

### 3. Inside the fastcgiapp.fcgi and backtoweb.frameworks

The fastcgiapp.fcgi is really just an empty shell. Its purpose is to load the backtoweb.framework which in turn will load the handlers bundle. 

When a HTTP request is provided by the fastcgi framework, the backtoweb framework creates a FCURLRequest object to encapsulate the request parameters and a FCResponseStream object to encapsulate the fastcgi response stream and pass them to the registered handlers.




