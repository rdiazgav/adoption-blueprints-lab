package com.retailflow.gateway;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

@RegisterRestClient(configKey = "recommendations")
@Produces(MediaType.APPLICATION_JSON)
public interface RecommendationsClient {

    @GET
    @Path("/recommendations/{customerId}")
    Response getRecommendations(@PathParam("customerId") String customerId);

    // Python service uses /health (not /q/health/live)
    @GET
    @Path("/health")
    Response liveness();
}
