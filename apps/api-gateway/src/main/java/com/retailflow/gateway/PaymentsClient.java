package com.retailflow.gateway;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

@RegisterRestClient(configKey = "payments")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public interface PaymentsClient {

    @POST
    @Path("/payments")
    Response processPayment(String body);

    @GET
    @Path("/q/health/live")
    Response liveness();
}
