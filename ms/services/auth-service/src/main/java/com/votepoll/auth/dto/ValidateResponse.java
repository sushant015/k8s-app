package com.votepoll.auth.dto;

public record ValidateResponse(boolean valid, String adminId, String email, String role) {}
