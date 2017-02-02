package de.fhg.aisec.ids.webconsole.api;

import java.util.Arrays;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Stream;

import javax.ws.rs.Consumes;
import javax.ws.rs.GET;
import javax.ws.rs.OPTIONS;
import javax.ws.rs.POST;
import javax.ws.rs.Path;

import org.osgi.service.prefs.BackingStoreException;
import org.osgi.service.prefs.Preferences;
import org.osgi.service.prefs.PreferencesService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.gson.GsonBuilder;
import com.google.gson.internal.Streams;
import com.google.gson.reflect.TypeToken;

import de.fhg.aisec.ids.webconsole.WebConsoleComponent;

/**
 * REST API interface for configurations in the connector.
 * 
 * The API will be available at http://localhost:8181/cxf/api/v1/config/<method>.
 * 
 * @author Julian Schuette (julian.schuette@aisec.fraunhofer.de)
 *
 */
@Path("/config")
public class ConfigApi {
	private static final Logger LOG = LoggerFactory.getLogger(ConfigApi.class);
	private static final String IDS_CONFIG_SERVICE = "ids-webconsole";
	
	@GET()
	@Path("list")
	public String get() {
		Optional<PreferencesService> cO = WebConsoleComponent.getConfigService();
		
		// if config service is not available at runtime, return empty map
		if (!cO.isPresent()) {
			return new GsonBuilder().create().toJson(new HashMap<>());
		}
		
		Preferences prefs = cO.get().getUserPreferences(IDS_CONFIG_SERVICE);
		HashMap<String, String> pMap = new HashMap<>();
		try {
			for (String key : prefs.keys()) {
				pMap.put(key, prefs.get(key,null));
			}
		} catch (BackingStoreException e) {
			LOG.error(e.getMessage(), e);
		}
		return new GsonBuilder().create().toJson(pMap);
	}

	@POST
	@OPTIONS
	@Path("set")
	@Consumes("application/json")
	public String set(String settings) {
		LOG.info("Received string " + settings);
		Map<String, String> result = new GsonBuilder().create().fromJson(settings, new TypeToken<HashMap<String, String>>() {}.getType());
		Optional<PreferencesService> cO = WebConsoleComponent.getConfigService();
		
		// if preferences service is not available at runtime, return empty map
		if (!cO.isPresent()) {
			return "no preferences service";
		}
		
		// Store into preferences service
		Preferences idsConfig = cO.get().getUserPreferences(IDS_CONFIG_SERVICE);
		if (idsConfig==null) {
			return "no preferences registered for pid " + IDS_CONFIG_SERVICE;
		}
		
		for (Iterator<String> iterator = result.keySet().iterator(); iterator.hasNext();) {
			String key = iterator.next();
			String value = result.get(key);
			idsConfig.put(key, value);
		}
		try {
			idsConfig.flush();
			return "ok";
		} catch (BackingStoreException e) {
			LOG.error(e.getMessage(), e);
			return e.getMessage();
		}		
	}
}
