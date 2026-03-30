package com.retailflow.gateway;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

@RegisterRestClient(configKey = "catalog")
@Produces(MediaType.APPLICATION_JSON)
public interface CatalogClient {

    @GET
    @Path("/products")
    Response listProducts();

    @GET
    @Path("/products/{id}")
    Response getProduct(@PathParam("id") Long id);

    @GET
    @Path("/products/chaos/enable")
    Response chaosEnable();

    @GET
    @Path("/products/chaos/disable")
    Response chaosDisable();

    @GET
    @Path("/q/health/live")
    Response liveness();
}
