package com.retailflow.orders;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.math.BigDecimal;
import java.util.List;

@Path("/orders")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@ApplicationScoped
public class OrderResource {

    @GET
    public List<Order> list(@QueryParam("customerId") String customerId) {
        if (customerId != null && !customerId.isBlank()) {
            return Order.findByCustomerId(customerId);
        }
        return Order.listAll();
    }

    @GET
    @Path("/{id}")
    public Response get(@PathParam("id") Long id) {
        Order order = Order.findById(id);
        if (order == null) {
            return Response.status(Response.Status.NOT_FOUND).build();
        }
        return Response.ok(order).build();
    }

    @POST
    @Transactional
    public Response create(@Valid CreateOrderRequest req) {
        Order order = new Order();
        order.customerId = req.customerId;
        order.totalAmount = req.items.stream()
                .map(i -> i.unitPrice.multiply(BigDecimal.valueOf(i.quantity)))
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        for (CreateOrderRequest.ItemRequest ir : req.items) {
            OrderItem item = new OrderItem();
            item.order = order;
            item.productId = ir.productId;
            item.productName = ir.productName;
            item.quantity = ir.quantity;
            item.unitPrice = ir.unitPrice;
            order.items.add(item);
        }

        order.persist();
        return Response.status(Response.Status.CREATED).entity(order).build();
    }

    @PATCH
    @Path("/{id}/status")
    @Transactional
    public Response updateStatus(@PathParam("id") Long id, @Valid UpdateStatusRequest req) {
        Order order = Order.findById(id);
        if (order == null) {
            return Response.status(Response.Status.NOT_FOUND).build();
        }
        order.status = req.status;
        return Response.ok(order).build();
    }
}
