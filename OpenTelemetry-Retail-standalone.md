# Distributed Traces with OpenTelemetry - Standalone

## Session Objectives

This is the first lab of the OpenTelemetry Enablement Series. It focuses on utilizing OpenTelemetry with Dynatrace to gain observability into your applications and services. We will only focus on ingesting traces for this lab, as metrics and logs will be covered in a separate series. We will cover the following:

1. Understanding Open-Telemetry and its use cases.
2. Open-Telemetry instrumentation types and Dynatrace support.
3. Setting up the sample Retail Application and Currency Service to generate traces.
4. Configuring Dynatrace to receive traces.
5. Open-Telemetry configurations in Dynatrace.

<!-- ------------------------ -->

## OpenTelemetry - Introduction

> OpenTelemetry is a collection of tools, APIs, and SDKs that allow users to instrument their applications to collect various sources of telemetry data (metrics, logs, traces). OpenTelemetry is a great alternative if trying to monitor a technology or framework the Dynatrace OneAgent doesn't support for automatic instrumentation and deep monitoring. With OpenTelemetry, you can manually instrument your applications and send the telemetry data to Dynatrace for aggregation and analysis.

## OpenTelemetry - Basic Terminology

- Trace -> Equivalent to a PurePath
- Span
- Context Propagation
- W3C Trace Context
  - Span id
  - Parent id
- Collector
  - Receiver
  - Processor
  - Exporter
- Automatic instrumentation
- Manual instrumentation

<!-- ------------------------ -->

## OpenTelemetry - Instrumentation Types and Dynatrace Support

There are three high-level steps involved in sending traces to Dynatrace.

- Instrumenting the application with OpenTelemetry.
- Preparing Dynatrace to receive the traces.
- Sending the traces to Dynatrace.

### 1.) Instrumenting the application with OpenTelemetry

The first step in getting traces to Dynatrace is instrumenting your code with OpenTelemetry to capture the telemetry data. There are two different approaches you can take: manual or automatic instrumentation. Manual instrumentation provides developers with a set of core tools (OpenTelemetry API & SDK) to manually configure the areas of their application they want monitored. If manual instrumentation isn't preferred, auto-instrumentation can be used. For every language/technology that OpenTelemetry supports, there are auto-instrumentation libraries provided for common frameworks used in the language. It is recommended to utilize auto-instrumentation libraries when possible as it reduces the chance of errors being introduced into your application and also reduces the amount of future maintenance required as the library author is responsible for maintaining the instrumentation instead of application developers.

For auto-instrumentation setups, generally all that's required is the library be imported into the application along with a setup call that provides some additonal context (Data source specific configuration, Exporter configuration, Propagator configuration, Resource configuration). (REWORD)

This lab will combine both forms of instrumentation. Our Retail Application uses manual instrumentation to capture some requests related to the cart functionality, while our Currency Service utilizes auto-instrumentation for telemetry. We will break down these instrumentations further in later steps.

### 2.) Preparing Dynatrace to receive our traces

There are two different options when it comes to sending OpenTelemetry traces to Dynatrace: The Dynatrace API or the OneAgent OpenTelemetry Sensors.

![With-OneAgent](assets/opentelemetry-withagent.png)

The Dynatrace OneAgent can tap-into OpenTelemetry running in your applications and send the data to Dynatrace. This can be accomplished by having a OneAgent running on the host along with the OpenTelemetry configuration pointing to a local endpoint. When using the OneAgent to ingest OpenTelemetry traces, there is no licensing cost incurred for the ingested traces.

![Without-OneAgent](assets/opentelemetry-withoutagent.png)

If you decide to use OpenTelemetry without a OneAgent, you will need to configure some form of exporter to send the traces to the Dynatrace API. Generally, an OpenTelemetry Collector is used to receive, process, and export telemetry data to an observability backend. It offers a vendor-agnostic implementation and removes the need to run, operate, and maintain multiple agents/collectors. However, an OpenTelemetry Collector is not explicitly required. You can simply use an OTLP/HTTP exporter that's provided with the Core SDK. At the moment, the Dynatrace API only supports the OTLP format. Ingesting traces through the API incurs a licensing cost for every span imported.

### 3.) Sending the traces to Dynatrace

Once you have completed the first two steps, the last step is to generate traces by interacting with your application. The OneAgent or configured exporter will automatically send the traces back to Dynatrace for aggregation and analysis. There are some additional configurations you can set in the Dynatrace UI, which will be covered later in this lab.

<!-- ------------------------ -->

## Retail Application Architecture

Before we begin, let's review the architecture of the Retail Application. There are two main components we need to be familiar with: the Retail Application and the Currency Service.

![App-Architecture](assets/app-architecture.png)

The Retail application is a simple Django app written in Python. It simulates a basic ecommerce website with various products that can be added to a cart and purchased. Our cart UI has a button labeled "Convert Currency" that can be used to convert the cart total from USD to EUR. Everytime the cart page is accessed, the Retail application makes an HTTP request to the Currency Service to convert the cart total from USD to EUR. When the button in the UI is clicked, a browser popup with the conversion total appears. The popup will display "-1" if an error has occurred.

The Currency service is a Node.js application written using the Express framework. It takes requests with a USD currency total and returns the appropriate EUR conversion.

<!-- ------------------------ -->

## Start the Currency Service

Lets begin by starting our Currency Service. Traverse to the Currency Service directory:

```bash
cd currencyservice
```

We need to install the node dependencies:

```bash
npm install
```

Set the PORT environment variable to 7000:

```bash
export PORT=7000
```

Start the Currency Service:

```bash
node server-http.js &
```

<!-- ------------------------ -->

## Start the Retail Application

Before we start our Retail Application, lets go into a little more detail regarding the manual instrumentation process for this application. When manually instrumenting applications/services, you're going to be using either the OpenTelemetry API, SDK, or both. Oftentimes there's a lot of confusion regarding the API, SDK, and when they're needed. An API is an application programming interface, and the OpenTelemetry API is the object we interface with to accomplish most of our monitoring needs.

When imported, the OpenTelemetry trace API creates a global singleton object that lives across the entire scope of your application/service. When we want to create a span to monitor a particular function within the application, we ask the OpenTelemetry API to give us a tracer object that can be called directly to create our spans. One important thing to note, is that the OpenTelemetry API does not come initialized with a functional TracerProvider - The object needed to create tracer objects - we need to configure one. This can be done by importing the TracerProvider class from the SDK, intializing an instance, and pairing it with the API via the set_tracer_provider() function. Without a functional TracerProvider configured, the OpenTelemetry trace API will use a NoopTracerProvider that NoOps (No Operation) when called, doing nothing. The OpenTelemetry API should only be used by itself if you are developing a library or another component that will be consumed by a runnable binary. This allows library authors to add OpenTelemetry instrumentation support without forcing the users of the library to actually utilize OpenTelemetry. If you're not developing a library to be consumed by another binary, then you will certainly need the OpenTelemetry SDK as it contains the implementations that will be used to monitor, process, and export your data.

Here is the code we use to setup OpenTelemetry for the Retail Application:

![retail-setup](assets/retail-setup.png)

We can then acquire a tracer and create spans like this:

![retail-tracer](assets/retail-tracer.png)

Navigate to the `/home/otelworkshop/retailapp` folder by using the following command:

```bash
cd ~/retailapp
```

Before we continue, we need to install the dependencies for the retail application. If prompted for a password, use the same one that was used to login.

```bash
./bin/devinstall
```

Copy the Nginx configuration file to the Host's Nginx configuration

```bash
sudo cp nginx.conf /etc/nginx/
```

Restart the Nginx Service

```bash
sudo service nginx restart
```

To properly run our Retail application, we need to gather the following information:

- API Token
- Dynatrace Tenant URL

### Generate API Token

1. Open your browser and access the Dynatrace URL.
2. Select **Access Tokens** from the Manage section of the Dynatrace navigation menu.
3. Click **Generate New Token** on the Access Tokens page.
4. Give your token a name, then add the `openTelemetryTrace.ingest` permission within the token scope.
5. Click **Generate Token** at the bottom of the page to create the API Token, make sure to copy the token value and save it somewhere you'll remember, as we won't be able to retreive this value again.

![generate-api-token](assets/create-api-token.png)

### Generate Dynatrace Trace Ingest Enpoint

Take your Tenant URL and append the value `/api/v2/otlp/v1/traces`. This will be your `DT_TENANT_URL`.

### Activate Virtual Environment & Configure Environment Variables

Now, we can activate the Retailapp virtual environment that our install script has setup for us:

```bash
source env/bin/activate
```

The values that were just noted need to be set as environment variables for the Retail Application. Open the setenv script and paste in the values for `DT_TENANT_URL` and `DT_API_TOKEN`:

```bash
nano bin/setenv
```

After pasting in the values, run the script to populate the current shell:

```bash
source bin/setenv
```

We can now start our application with Gunicorn. Navigate to the src directory and run the application:

```bash
cd src
gunicorn --bind 0.0.0.0:3005 ecommerce.wsgi:application -c gunicorn.config.py
```

Verify the application started successfully by accessing `AWS-IP:80` in your browser.

<!-- ------------------------ -->

## Load Retailapp in Browser And View Traces in Dynatrace

Since the Retail Application is utilizing manual instrumentation, only the parts of the application we instrumented will generate traces. For this lab, most of the functionality surrounding the cart is instrumented. Create an account on the Retail Application to begin adding items to it. Once logged in, add items to your cart and navigate to the cart page to view your total. If the steps were followed correctly, clicking on the convert button should generate a browser pop-up that will display our total in Euro's.

After loading the application in your browser and testing the cart functionality, you should notice that something is broken. Our convert button is returning a "-1". Let's take a closer look in Dynatrace to see what's happening. If we look at the generated traces on the distributed traces page, there's a span event on our request indicating the request has failed. In order to view attributes and event attributes in Dynatrace Traces, they need to be whitelisted first. Go ahead and whitelist the event attribute, then generate some more traces so we can get details regarding the request failure.

<!-- ADD IMAGE FOR SPAN EVENT MESSAGE -->

After generating addional traces, you should now be able to see the `error_message` event attribute that was raised on the Python application following the attempted conversion request. It appears that our Python application is reaching out to port 6999, instead of the port we set the Currency Service to listen on (7000). We should be able to fix the problem by adjusting the `CURRENCYSERVICE_URL` environment variable in our setenv script.

Hit `Ctr + C` to stop the application.

Open our setenv script

```bash
nano ../bin/setenv
```

Adjust the value of `CURRENCYSERVICE_URL` to `http://localhost:7000`, then save and close the file.

We need to reset the environment varables

```bash
source ../bin/setenv
```

Now, start the Retail Application again and try to convert the currency.

```bash
gunicorn --bind 0.0.0.0:3005 ecommerce.wsgi:application -c gunicorn.config.py &
```

<!-- ------------------------ -->

## Whitelist Additional Attributes

Lets take a closer look at the traces we generated. Navigate to the Distributed Traces page within the Applications & Microservices menu section and click into the `Request to Currency Service` PurePath. If we resolved our previous issue, you should notice that the newly ingested spans no longer contain a span event indicating a request failure. Instead, you should see two sections 'Attributes' and 'Resource Attributes' within the trace summary.

![attributes](assets/attributes.png)

OpenTelemetry allows you to provide metadata about your Resources and the Spans they emit via key-value pairs called attributes. We have created a span attribute called `conversion_total` to track the conversion amount returned by the Currency Service. It can be seen that Dynatrace is detecting it within the span attribute section. Like Span event attributes, span attributes need to be whitelisted in Dynatrace in order to show up within Traces. To whitelist the span attribute, you can either do it directly from the indicators in the trace summary or from the Server-side service monitoring section of the Settings menu. Note that we won't see the attribute values in Dynatrace until we generate more traces.

<!-- ------------------------ -->

## Enable Auto-Instrumentation on Currency Service

In this step, you will be stopping the running instance of our Currency Service and starting another with auto-instrumentation enabled for additional visibility in Dynatrace. Let's go over auto-instrumentation in some more detail before continuing. Similar to manual instrumentation, the goal of auto-instrumentation is to create observability in our application. The main difference here is who maintains the instrumentation. While manual instrumentation requires the application authors to instrument and maintain the application how they see fit, automatic instrumentation allows the application authors to use already instrumented libraries and push the maintenance responsibility back to the library authors. In our Currency Service, we're utilizing the common Express framework to run our serivce. Luckily, OpenTelemetry provides an auto-instrumentation package for the Express framework. All we need to do is configure the exporters and processors needed to process and export the data, as well as a Resource object defining the resource that is to be monitored. After that, a simple setup call will begin the instrumentation.

Navigate back to the Currency Service directory:

```bash
cd ~/currencyservice
```

Get the Process Id of the Currency Service:

```bash
ps
```

Look for the node process under the CMD column and note the PID. We will use it in our next command to kill the process:

```bash
kill -9 <PID>
```

![kill-process](assets/kill-process.png)

We need to set some additional environment variables so OpenTelemetry knows where to send the telemetry data. Open the setenv script and paste in your API token and Tenant URL to the `DT_TENANT_URL_CS` and `DT_API_TOKEN_CS` lines:

```bash
nano bin/setenv
```

Next, run the script:

```bash
source bin/setenv
```

Now, we'll run the Currency Service with OpenTelemetry instrumentation:

```bash
node --require ./tracing.js server-http.js &
```

After going back to `AWS-IP:80` and generating traffic, we should see both Retail App and Currency Service spans showing up on the Distributed Traces page. If you click back into the `Request to Currency Service` trace, we should also see the `conversion_total` attribute now displaying properly.

<!-- ------------------------ -->

## Enable Context Propagation

Since they were part of the same transaction, wouldn't it be nice if our Currency Service's spans were nested within the Retail Application's HTTP request spans? We can do this with Context propagation. Context propagation allows us to connect spans from different processes all within the same trace. Our Retail application will use the `traceparent` HTTP header described in the W3C TraceContext standard to propagate the span information over to the Currency Service. Since the Currency Service uses an auto-instrumentation library for the HTTP & Express frameworks in Node.js, it will automatically create a child span based on the context from the `traceparent` header and Dynatrace will be able to link the two together. Note that if the Currency Service was manually instrumented like the Retail Application, we would have to manually extract the `traceparent` data and apply them to the new spans that are about to be created.

For this lab, all we need to do to enable context propagation is set the `CONTEXT_PROPAGATION` environment variable to true prior to starting the retail application. Set the value to TRUE, then restart the retail application.

Navigate back to the Retail Application directory and stop the currently running instance:

```bash
cd ~/retailapp
ps
kill -9 <PID>
```

Set the `CONTEXT_PROPAGATION` environment variable

```bash
export CONTEXT_PROPAGATION="TRUE"
```

Start the retail app

```bash
cd src
gunicorn --bind 0.0.0.0:3005 ecommerce.wsgi:application -c gunicorn.config.py &
```

<!-- ------------------------ -->

## Load Retailapp again

Re-visit the retail application in your browser and add a few more items to your cart. After visiting your cart, you should notice nested traces beginning to appear in your Dynatrace tenant.
