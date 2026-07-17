package com.votepoll.auth.dto;

public record LoginResponse(String token, String adminId, String email, String role) {}
