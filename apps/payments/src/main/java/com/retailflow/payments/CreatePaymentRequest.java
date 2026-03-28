package com.retailflow.payments;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.math.BigDecimal;

public class CreatePaymentRequest {

    @NotBlank
    public String orderId;

    @NotBlank
    public String customerId;

    @NotNull
    @Positive
    public BigDecimal amount;
}
