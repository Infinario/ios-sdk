<h1 class="mtn">iOS SDK</h1>
The INFINARIO iOS SDK is available at this Git repository: <a href="https://github.com/Infinario/ios-sdk">https://github.com/Infinario/ios-sdk</a>.
<h2>Installation</h2>
<ol>
	<li>Download the <a href="https://github.com/infinario/android-sdk/releases">lastest release</a> of the iOS SDK</li>
	<li>Unzip / untar the downloaded SDK into a preferred directory</li>
	<li>Locate file <strong>InfinarioSDK.xcodeproj</strong> in the unpacked SDK directory</li>
	<li>Drag &amp; drop the file <strong>InfinarioSDK.xcodeproj</strong> to your <strong>XCode project</strong> in <strong>Project navigator</strong></li>
	<li>In XCode, click on your project in Project navigator, scroll down the <strong>General tab</strong> and locate <strong>Embedded Binaries</strong> section</li>
	<li>Click on the <strong>Plus sign</strong> button (titled <em>Add items</em>)</li>
        <li>In the newly opened dialog window, please select <strong>InfinarioSDK.framework</strong> under <em>&lt;Your project&gt;</em> &gt; InfinarioSDK.xcodeproj &gt; Products and click <strong>Add</strong></a>
</li>
</ol>

<p style="text-align: justify;">After completing the steps above, the INFINARIO iOS SDK should be included in your app, ready to be used.</p>

<h2>Usage</h2>
<h3>Basic Interface</h3>
<p style="text-align: justify;">
Once the IDE is set up, you may start using the INFINARIO library in your code. Firstly, you need to import main header file <strong>InfinarioSDK.h</strong> with the following code: <code>#import &lt;InfinarioSDK/InfinarioSDK.h&gt;</code>. Secondly, you need to know the URI of your INFINARIO API instance (usually <code>https://api.infinario.com</code>)and your project <code>token</code> (located on the Project management / Overview page in the web application). To interact with the INFINARIO SDK, you need to obtain a shared instance of the INFINARIO class using the project <code>token</code> (the URI parameter is optional):</p>

<pre><code>// Use public Infinario instance
Infinario *infinario = [Infinario sharedInstanceWithToken:@"your_project_token"];

// Use custom Infinario instance
Infinario *infinario = [Infinario sharedInstanceWithToken:@"your_project_token" andWithTarget:@"http://url.to.your.instance.com"];
</code></pre>
<p style="text-align: justify;">To start tracking, the customer needs to be identified with their unique <code>customerId</code>. The unique <code>customerId</code> can either be an instance of NSString, or NSDictionary representing the <code>customerIds</code> as referenced in <a href="http://guides.infinario.com/technical-guide/rest-client-api/#Detailed_key_descriptions">the API guide</a>. Setting</p>

<pre><code>NSString *customerId = @"123-foo-bar";</code></pre>
is equivalent to
<pre><code>NSDictionary *customerId = @{@"registered": @"123-foo-bar"};</code></pre>
In order to identify a customer, call one of the <code>identifyWithCustomer</code> or <code>identifyWithCustomerDict</code> methods on the obtained INFINARIO instance as follows:
<pre><code>// Identify a customer with their NSString customerId
[infinario identifyWithCustomer:customerId];

// Identify a customer with their NSDictionary customerId
[infinario identifyWithCustomerDict:customerId];</code></pre>
<p style="text-align: justify;">The identification is performed asynchronously and there is no need to wait for it to finish. Until they are sent to the INFINARIO API, all tracked events are stored in the internal SQL database.</p>
<p style="text-align: justify;">You may track any event by calling the <code>track</code> method on the INFINARIO instance. The <code>track</code> method takes one mandatory and two optional arguments. The first argument is a <code>NSString *type</code> argument categorizing your event. This argument is <strong>required</strong>. You may choose any string you like.</p>
<p style="text-align: justify;">The next two arguments are <code>NSDictionary *properties</code> and <code>NSNumber *timestamp</code>. Properties is a dictionary which uses <code>NSString</code> keys and the value may be any <code>NSObject</code> which is serializable to JSON. Properties can be used to attach any additional data to the event. Timestamp is a standard UNIX timestamp in seconds and it can be used to mark the time of the event's occurrence. The default timestamp is preset to the time when the event is tracked.</p>

<pre><code>NSDictionary *properties = @{@"item_id": @45};
NSNumber *timestamp = [NSNumber numberWithLong:[[NSDate date] timeIntervalSince1970]];

// Tracking of buying an item with item's properties at a specific time
[infinario track:@"item_bought" withProperties:properties withTimestamp:timestamp];

// Tracking of buying an item at a specific time
[infinario track:@"item_bought" withTimestamp:timestamp];

// Tracking of buying an item with item's properties
[infinario track:@"item_bought" withProperties:properties];

// Basic tracking that an item has been bought
[infinario track:@"item_bought"];
</code></pre>
<p style="text-align: justify;">The INFINARIO iOS SDK provides you with means to store arbitrary data that is not event-specific (e.g. customer age, gender, initial referrer). Such data is tied directly to the customer as their properties. To store such data, the <code>update</code> method is used.</p>

<pre><code>NSDictionary *properties = @{@"age": @34};

// Store customer's age
[infinario update:properties];
</code></pre>

<h2>Automatic events</h2>
<p>
INFINARIO iOS SDK automatically tracks some events on its own. Automatic events ensure that basic user data gets tracked with as little effort as just including the SDK into your game. Automatic events include sessions, installation, identification and payments tracking.
</p>

<h3>Sessions</h3>
<p>
Session is a time spent in the game, it starts when the game is launched and ends when the game gets dismissed and is freed from memory. Automatic tracking of sessions produces two events, <code>session_start</code> and <code>session_end</code>. Both events contain the timestamp of the occurence together with basic attributes about the device (OS, OS version, SDK, SDK version and device model). Event <code>session_end</code> contains also the duration of the session in seconds. Example of <code>session_end</code> event attributes in <em>JSON</em> format:
</p>

<pre><code>{
  "duration": 125,
  "device_model": "iPhone",
  "device_type": "mobile",
  "ip": "10.0.1.58",
  "os_name": "iOS",
  "os_version": "8.1.0",
  "sdk": "iOS SDK",
  "sdk_version": "1.0.5"
  "app_version": "1.0.0"
}
</code></pre>

<h3>Installation</h3>

<p>
Installation event is fired <strong>only once</strong> for the whole lifetime of the game on one device when the game is launched for the first time. Besides the basic information about the device (OS, OS version, SDK, SDK version and device model), it also contains additional attribute called <strong>campaign_id</strong> which identifies the source of the installation. For more information about this topic, please refer to the <a href="http://guides.infinario.com/user-guide/acquisition/">aquisition documentation</a>. Example of installation event:
</p>

<pre><code>{
  "campaign": "Advertisement on my website",
  "campaign_id": "ui9fj4i93jf9083094fj9043",
  "link": "https://itunes.apple.com/us/...",
  "device_model": "iPhone",
  "device_type": "mobile",
  "ip": "10.0.1.58",
  "os_name": "iOS",
  "os_version": "8.1.0",
  "sdk": "iOS SDK",
  "sdk_version": "1.0.5"
}
</code></pre>

<h3>Identification</h3>

<p>
Identification event is tracked each time the <code>identify()</code> method is called. It contains all basic information regarding the device (OS, OS version, SDK, SDK version and device model) as well as <strong>registered</strong> attribute which identifies the player. Example of an identification event:
</p>

<pre><code>{
  "registered": "player@email.com",
  "device_model": "iPhone",
  "device_type": "mobile",
  "ip": "10.0.1.58",
  "os_name": "iOS",
  "os_version": "8.1.0",
  "sdk": "iOS SDK",
  "sdk_version": "1.0.5"
}
</code></pre>

<h3>Payments</h3>

<p>
INFINARIO iOS SDK automatically tracks all payments made in the game as the SDK instance listens on <code>[SKPaymentQueue defaultQueue]</code> for successful transactions. Purchase events (called <code>hard_purchase</code>) contain all basic information about the device (OS, OS version, SDK, SDK version and device model) combined with additional purchase attributes <strong>brutto</strong>, <strong>item_id</strong> and <strong>item_title</strong>. <strong>Brutto</strong> attribute contains price paid by the player. Attribute <strong>item_title</strong> consists of human-friendly name of the bought item (e.g. Silver sword) and <strong>item_id</strong> corresponds to the product identifier for the in-app purchase as defined in your iTunes Connect console. Example of purchase event: 
</p>

<pre><code>{
  "gross_amount": 0.911702,
  "currency": "EUR",
  "payment_system": "iTunes Store",
  "product_id": "silver.sword",
  "product_title": "Silver sword",
  "device_model": "iPad",
  "device_type": "tablet",
  "ip": "10.0.1.58",
  "os_name": "iOS",
  "os_version": "8.1.0",
  "sdk": "iOS SDK",
  "sdk_version": "1.0.5"
}
</code></pre>

<h2>Virtual payment</h2>

<p>If you use virtual payments (e.g. purchase with in-game gold, coins, ...) in your project, you can track them with a call to <code>trackVirtualPayment</code>.</p>

<pre><code>[infinario trackVirtualPayment:@"currency" withAmount:@3 withItemName:@"itemName" withItemType:@"itemType"];</code></pre>

<h2>Push notifications</h2>
<p style="text-align: justify;">The INFINARIO web application allows you to easily create complex scenarios which you can use to send push notifications directly to your players. The following section explains how to enable receiving push notifications in the INFINARIO iOS SDK.</p>

<h3>Apple Push certificate</h3>

<p style="text-align: justify;">For push notifications to work, you need a push notifications certificate with a corresponding private key in a single file in PEM format. The following steps show you how to export one from the Keychain Access application on your Mac:</p>

<ol>
    <li>Launch Keychain Access application on your Mac</li>
    <li>Find Apple Push certificate for your app in <em>Certificates</em> or <em>My certificates</em> section (it should start with <strong>&quot;Apple Development IOS Push Services:&quot;</strong> for development certificate or <strong>&quot;Apple Production IOS Push Services:&quot;</strong> for production certificate)</li>
    <li>The certificate should contain a <strong>private key</strong>, select both certificate and its corresponding private key, then right click and click <strong>Export 2 items</strong></li>
<li>In the saving modal window, choose a filename and saving location which you prefer and select the file format <strong>Personal Information Exchange (.p12)</strong> and then click <strong>Save</strong></li>
<li>In the next modal window, you will be prompted to choose a password, leave the password field blank and click <strong>OK</strong>. Afterwards, you will be prompted with you login password, please enter it.</li>
<li>Convert p12 file format to PEM format using OpenSSL tools in terminal. Please launch <strong>Terminal</strong> and navigate to the folder, where the .p12 certificate is saved (e.g. <code>~/Desktop/</code>)</li>
<li>Run the following command <code>openssl pkcs12 -in certificate.p12 -out certificate.pem -clcerts -nodes</code>, where <strong>certificate.p12</strong> is the exported certificate from Keychain Access and <strong>certificate.pem</strong> is the converted certificate in PEM format containing both Apple Push certificate and its private key</li>
<li>The last step is to upload the Apple Push certificate to the INFINARIO web application. In the INFINARIO web application, navigate to <strong>Project management -&gt; Settings -&gt; Notifications</strong></li>
<li>Copy the content of <strong>certificate.pem</strong> into <strong>Apple Push Notifications Certificate</strong> and click <strong>Save</strong>
</ol>

<p style="text-align: justify;">
Now you are ready to implement Push Notifications into your iOS application.
</p>

<h3>INFINARIO iOS SDK</h3>
<p style="text-align: justify;">By default, receiving of push notifications is disabled. You can enable it by calling the <code>registerPushNotifications </code>method. Please note that this method needs to be called only once. Push notifications remain enabled until they are unregistered. After registering for push notifications, iOS automatically calls <code>didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken</code> which is a good place to send the device token to the INFINARIO web application using method <code>addPushNotificationsToken</code>. See code sample from <strong>AppDelegate.m</strong> below and <a target="_blank" href="https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Introduction.html">Apple Push Notifications Documentation</a> for more details.</p>

<pre><code>- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // self.infinario is @property Infinario *infinario;
    self.infinario = [Infinario sharedInstanceWithToken:@"your_token" andWithCustomer:@"some_player_id"];
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"token: %@", deviceToken);
    [self.infinario addPushNotificationsToken:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"failed obtaining token: %@", error);
}</code></pre>
