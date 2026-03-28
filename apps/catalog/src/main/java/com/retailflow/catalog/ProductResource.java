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

    @GET
    public List<Product> list(@QueryParam("category") String category) {
        if (category != null && !category.isBlank()) {
            return Product.findActiveByCategory(category);
        }
        return Product.findActive();
    }

    @GET
    @Path("/{id}")
    public Response get(@PathParam("id") Long id) {
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
