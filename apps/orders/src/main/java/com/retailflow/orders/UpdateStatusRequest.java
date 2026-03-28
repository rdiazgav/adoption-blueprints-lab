package com.retailflow.orders;

import jakarta.validation.constraints.NotNull;

public class UpdateStatusRequest {

    @NotNull
    public OrderStatus status;
}
