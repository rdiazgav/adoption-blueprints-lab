package com.retailflow.catalog;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.util.List;

@Path("/products")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@ApplicationScoped
public class ProductResource {

    private static volatile boolean chaosEnabled = false;

    @GET
    @Path("/chaos/enable")
    public Response chaosEnable() {
        chaosEnabled = true;
        return Response.ok("{\"chaos\":\"enabled\"}").build();
    }

    @GET
    @Path("/chaos/disable")
    public Response chaosDisable() {
        chaosEnabled = false;
        return Response.ok("{\"chaos\":\"disabled\"}").build();
    }

    @GET
    public Response list(@QueryParam("category") String category) {
        if (chaosEnabled) return Response.status(503).entity("{\"error\":\"Service unavailable\"}").build();
        List<Product> products = (category != null && !category.isBlank())
                ? Product.findActiveByCategory(category)
                : Product.findActive();
        return Response.ok(products).build();
    }

    @GET
    @Path("/{id}")
    public Response get(@PathParam("id") Long id) {
        if (chaosEnabled) return Response.status(503).entity("{\"error\":\"Service unavailable\"}").build();
        Product product = Product.findById(id);
        if (product == null || !product.active) {
            return Response.status(Response.Status.NOT_FOUND).build();
        }
        return Response.ok(product).build();
    }

    @POST
    @Transactional
    public Response create(@Valid CreateProductRequest req) {
        Product product = new Product();
        product.name = req.name;
        product.description = req.description;
        product.category = req.category;
        product.price = req.price;
        product.stock = req.stock;
        product.persist();
        return Response.status(Response.Status.CREATED).entity(product).build();
    }

    @PUT
    @Path("/{id}")
    @Transactional
    public Response update(@PathParam("id") Long id, @Valid UpdateProductRequest req) {
        Product product = Product.findById(id);
        if (product == null || !product.active) {
            return Response.status(Response.Status.NOT_FOUND).build();
        }
        product.name = req.name;
        product.description = req.description;
        product.category = req.category;
        product.price = req.price;
        product.stock = req.stock;
        return Response.ok(product).build();
    }

    @DELETE
    @Path("/{id}")
    @Transactional
    public Response delete(@PathParam("id") Long id) {
        Product product = Product.findById(id);
        if (product == null || !product.active) {
            return Response.status(Response.Status.NOT_FOUND).build();
        }
        product.active = false;
        return Response.noContent().build();
    }
}
