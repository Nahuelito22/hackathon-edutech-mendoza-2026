/**
 * HEM2026 - Cliente de Supabase
 * Este archivo configurará la conexión con Supabase.
 * Se completará cuando se integre el backend.
 */

import { createClient } from '@supabase/supabase-js';
//
const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;
//
export const supabase = createClient(supabaseUrl, supabaseAnonKey);
