import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client with Service Role Key for administrative tasks
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    console.log('Iniciando limpieza de tickets SOS expirados...')

    // Lógica: Expirar tickets 'pendiente' con más de 30 minutos de antigüedad
    const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000).toISOString()

    const { data: expiredPendientes, error: errorPendientes } = await supabaseClient
      .from('help_requests')
      .update({ status: 'expirado' })
      .eq('status', 'pendiente')
      .lt('created_at', thirtyMinutesAgo)
      .select()

    if (errorPendientes) throw errorPendientes

    // Opcional: Expirar tickets 'en_camino' que llevan demasiado tiempo (ej: > 1 hora)
    // Esto previene tickets que nunca se cerraron por el mentor
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString()
    const { data: expiredEnCamino, error: errorEnCamino } = await supabaseClient
      .from('help_requests')
      .update({ status: 'expirado' })
      .eq('status', 'en_camino')
      .lt('started_at', oneHourAgo)
      .select()

    if (errorEnCamino) throw errorEnCamino

    const totalExpired = (expiredPendientes?.length || 0) + (expiredEnCamino?.length || 0)
    
    console.log(`Limpieza completada. Tickets expirados: ${totalExpired}`)

    return new Response(
      JSON.stringify({ 
        success: true, 
        expired_pendientes: expiredPendientes?.length || 0,
        expired_en_camino: expiredEnCamino?.length || 0,
        total: totalExpired
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    )

  } catch (error) {
    console.error('Error en la función de expiración:', error.message)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500 
      }
    )
  }
})
