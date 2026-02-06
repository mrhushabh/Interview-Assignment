// Type declarations for Deno runtime and Edge Functions
// This file helps IDEs understand Deno globals and URL imports

declare namespace Deno {
  export interface Env {
    get(key: string): string | undefined;
    set(key: string, value: string): void;
    delete(key: string): void;
    has(key: string): boolean;
    toObject(): { [key: string]: string };
  }

  export const env: Env;

  export function serve(
    handler: (request: Request) => Response | Promise<Response>
  ): void;

  export function test(name: string, fn: () => void | Promise<void>): void;
}

// Supabase client type declarations
declare module "https://esm.sh/@supabase/supabase-js@2.47.0" {
  export interface SupabaseClient {
    from(table: string): any;
    auth: {
      getUser(): Promise<{ data: { user: any }; error: any }>;
    };
  }

  export function createClient(
    supabaseUrl: string,
    supabaseKey: string,
    options?: { global?: { headers?: Record<string, string> } }
  ): SupabaseClient;
}

// Deno testing assertions
declare module "https://deno.land/std@0.168.0/testing/asserts.ts" {
  export function assertEquals<T>(actual: T, expected: T, msg?: string): void;
  export function assertExists<T>(actual: T, msg?: string): void;
}
