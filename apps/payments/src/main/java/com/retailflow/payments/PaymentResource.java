package com.retailflow.payments;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.util.Map;
import java.util.random.RandomGenerator;

@Path("/payments")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@ApplicationScoped
public class PaymentResource {

    @ConfigProperty(name = "app.version", defaultValue = "v1")
    String version;

    private final RandomGenerator rng = RandomGenerator.getDefault();

    @GET
    @Path("/version")
    public Map<String, String> version() {
        return Map.of("version", version);
    }

    @GET
    @Path("/{orderId}")
    public Response getByOrderId(@PathParam("orderId") String orderId) {
        Payment payment = Payment.findByOrderId(orderId);
        if (payment == null) {
            return Response.status(Response.Status.NOT_FOUND).build();
        }
        return Response.ok(payment).build();
    }

    @POST
    @Transactional
    public Response process(@Valid CreatePaymentRequest req) {
        Payment payment = new Payment();
        payment.orderId = req.orderId;
        payment.customerId = req.customerId;
        payment.amount = req.amount;
        payment.status = PaymentStatus.PENDING;

        if ("v2".equals(version)) {
            payment.status = processV2();
        } else {
            payment.status = PaymentStatus.APPROVED;
        }

        payment.persist();
        return Response.status(Response.Status.CREATED).entity(payment).build();
    }

    @POST
    @Path("/{id}/refund")
    @Transactional
    public Response refund(@PathParam("id") Long id) {
        Payment payment = Payment.findById(id);
        if (payment == null) {
            return Response.status(Response.Status.NOT_FOUND).build();
        }
        if (payment.status != PaymentStatus.APPROVED) {
            return Response.status(Response.Status.CONFLICT)
                    .entity(Map.of("error", "Only APPROVED payments can be refunded"))
                    .build();
        }
        payment.status = PaymentStatus.REFUNDED;
        return Response.ok(payment).build();
    }

    // v2: 500ms delay, 80% APPROVED / 20% DECLINED — simulates degraded service
    private PaymentStatus processV2() {
        try {
            Thread.sleep(500);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        return rng.nextDouble() < 0.8 ? PaymentStatus.APPROVED : PaymentStatus.DECLINED;
    }
}
